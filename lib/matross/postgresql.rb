dep_included? 'pg'

_cset(:database_config)                  { "#{shared_path}/config/database.yml" }
_cset(:postgresql_user)                  { user }
_cset(:postgresql_backup_script)         { "#{shared_path}/matross/postgresql_backup.sh" }
_cset :postgresql_backup_cron_schedule,  '30 3 * * *'


namespace :postgresql do

  desc 'Create the database.yml file in shared path. User is created if needed'
  task :setup, :roles => [:app, :dj] do
    run "mkdir -p #{shared_path}/config"
    template "postgresql/database.yml.erb", database_config
    user_count = capture(%W{ sudo -u postgres psql postgres -tAc
                             "SELECT 1 FROM pg_roles
                              WHERE rolname='#{postgresql_user}'" } * ' ').to_i
    if user_count == 0
      run "#{sudo} -u postgres createuser -d -r -s #{postgresql_user}"
    else
      logger.info 'User already created, skpping'
    end
  end
  after 'deploy:setup', 'postgresql:setup'

  desc 'Update the symlink for database.yml for deployed release'
  task :symlink, :roles => [:app, :dj] do
    run "ln -nfs #{database_config} #{release_path}/config/database.yml"
  end
  after 'bundle:install', 'postgresql:symlink'

  desc "Create the database and load the schema"
  task :create, :roles => :db do
    db_count = capture(%W{ #{sudo} -u postgres psql -lqt |
                           cut -d \\| -f 1 |
                           grep -w #{postgresql_database.gsub("-", "_")} |
                           wc -l } * ' ').to_i
    if db_count == 0
      run %W{ cd #{release_path} &&
              RAILS_ENV=#{rails_env.to_s.shellescape}
              bundle exec rake db:create db:schema:load } * ' '
    else
      logger.info 'DB is already configured, skipping'
    end
  end
  after 'postgresql:symlink', 'postgresql:create'

  namespace :backup do

    # This routine is heavily inspired by whenever's approach
    # https://github.com/javan/whenever
    desc 'Update the crontab with the backup entry'
    task :setup, :roles => :db do
      template "postgresql/backup.sh.erb", postgresql_backup_script
      run "chmod +x #{postgresql_backup_script}"

      comment_open  = '# Begin Matross generated task for PostgreSQL Backup'
      comment_close = '# End Matross generated task for PostgreSQL Backup'

      cron_command = "#{postgresql_backup_script} >> #{shared_path}/log/postgresql_backup.log 2>&1"
      cron_entry   = "#{postgresql_backup_cron_schedule} #{cron_command}"
      cron         = [comment_open, cron_entry, comment_close].compact.join("\n")

      current_crontab = ''
      begin
        # Some cron implementations require all non-comment lines to be
        # newline-terminated. Strip all newlines and replace with the default
        # platform record seperator ($/)
        current_crontab = capture("crontab -l -u #{user} 2> /dev/null").gsub!(/\s+$/, $/)
      rescue Capistrano::CommandError
        logger.debug 'The user has no crontab'
      end
      contains_open_comment  = current_crontab =~ /^#{comment_open}\s*$/
      contains_close_comment = current_crontab =~ /^#{comment_close}\s*$/

      # If an existing identier block is found, replace it with the new cron entries
      if contains_open_comment && contains_close_comment
        updated_crontab = current_crontab.gsub(/^#{comment_open}\s*$.+^#{comment_close}\s*$/m, cron.chomp)
      else  # Otherwise, append the new cron entries after any existing ones
        updated_crontab = current_crontab.empty? ? cron : [current_crontab, cron].join("\n")
      end.gsub(/\n{2,}/, "\n")  # More than one newline becomes just one.

      temp_crontab_file = "/tmp/matross_#{user}_crontab"
      put updated_crontab, temp_crontab_file
      run "crontab -u #{user} #{temp_crontab_file}"
      run "rm #{temp_crontab_file}"
    end
  end
end
