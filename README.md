# matross

## Usage

Put `matross` in the `:development` group of your `Gemfile`:

```ruby
group :development do
  gem 'matross'
end
```

Run `bundle exec capify .` in the project root folder:

```bash
$ bundle exec capify .
```

## What's inside?

We made a bunch of additions and customizations. Below we list the most relevant ones.

* **Foreman by default**:
* **Custom foreman upstart template**: we use a custom upstart template, that enables `console log`, allowing `logrotate` to work properly.

## Overriding default templates

We have our opinions, but don't know everything. What works for us, may not fit your needs since each app is a unique snowflake. To take care of that `matross` allows you to define your own templates to use instead of the built in ones. Look at the included ones in `lib/matross/templates` to see how we think things should go.

## Managing application daemons with Foreman

Foreman has freed us of the tedious task of writing `init` and Upstart scripts. Some of our `matross` recipes automatically add processes - such as the `unicorn` server - to the `Procfile`.

If you have an application Procfile with custom daemons defined, such as Rake task, they will be concatenated with all the processes defined in `matross`, resulting in one final `Procfile-matross` file that will be used to start your application and export init scrips.

You can specify the number of each instance defined in Procfile-matross using the `foreman_procs` variable.
Suppose you have a process called `dj` and want to export 3 instances of it:

```ruby
set :foreman_procs, {
    dj: 3
}
```

We also modified the default upstart template to log through upstart instead of just piping stdout and stderr into files. Goodbye nocturnal logexplosion. (Like all templates you can override it!)

## Recipes

### Foreman

Requires having [`foreman`](http://rubygems.org/gems/foreman) available in the application. As mentioned before, we use `foreman` in production to save us from generating upstart init scripts. As a bonus we get sane definition of environment variables.

Overwritable template: [`process.conf.erb`](lib/matross/templates/foreman/process.conf.erb)

> Variables

| Variable         | Default value                               | Description                                                    |
| ---              | ---                                         | ---                                                            |
| `:foreman_user`  | `{ user }` - The user defined in Capistrano | The user which should run the tasks defined in the `Procfile`  |
| `:foreman_bin`   | `'bundle exec foreman'`                     | The `foreman` command                                          |
| `:foreman_procs` | `{}` - Defaults to one per task definition  | Number of processes for each task definition in the `Procfile` |

> Tasks

| Task                | Description                                                                       |
| ---                 | ---                                                                               |
| `foreman:pre_setup` | Creates the `upstart` folder in the `shared_path`                                 |
| `foreman:setup`     | Merges all partial `Procfile`s and `.env`s, including the appropriate `RAILS_ENV` |
| `foreman:export`    | Export the task definitions as Upstart scripts                                    |
| `foreman:symlink`   | Symlink `.env-matross` and `Procfile-matross` to `current_path`                   |
| `foreman:log`       | Symlink Upstart logs to the log folder in  `shared_path`                          |
| `foreman:stop`      | Stop all of the application tasks                                                 |
| `foreman:restart`   | Restart or start all of the application tasks                                     |
| `foreman:remove`    | Remove all of the application tasks from Upstart                                  |

### Unicorn

Requires having [`unicorn`](http://unicorn.bogomips.org/index.html) available in the application. By loading our `unicorn` recipe, you get [our default configuration](lib/matross/templates/unicorn/unicorn.rb.erb).

Overwritable template: [`unicorn.rb.erb`](lib/matross/templates/unicorn/unicorn.rb.erb)
Procfile task: `web: bundle exec unicorn -c <%= unicorn_config %> -E <%= rails_env %>`

> Variables

| Variable           | Default value                        | Description                        |
| ---                | ---                                  | ---                                |
| `:unicorn_config`  | `"#{shared_path}/config/unicorn.rb"` | Location of the configuration file |
| `:unicorn_log`     | `"#{shared_path}/log/unicorn.log"`   | Location of unicorn log            |
| `:unicorn_workers` | `1`                                  | Number of unicorn workers          |

> Tasks

| Task               | Description                                                      |
| ---                | ---                                                              |
| `unicorn:setup`    | Creates the `unicorn.rb` configuration file in the `shared_path` |
| `unicorn:procfile` | Defines how `unicorn` should be run in a temporary `Procfile`    |


### Nginx

This recipes creates and configures the virtual_host for the application. [This virtual host] has some sane defaults, suitable for most of our deployments (non-SSL). The file is created at `/etc/nginx/sites-available` and symlinked to `/etc/nginx/sites-enabled`. These are the defaults for the Nginx installation in Ubuntu. You can take a look at [our general `nginx.conf`](https://github.com/innvent/parcelles/blob/puppet/puppet/modules/nginx/files/nginx.conf).

> Variables

| Variable    | Default value | Description                      |
| ---         | ---           | ---                              |
| `:htpasswd` | None          | `htpasswd` user:passwordd format |

> Tasks

| Task           | Description                                       |
| ---            | ---                                               |
| `nginx:setup`  | Creates the virtual host file                     |
| `nginx:reload` | Reloads the Nginx configuration                   |
| `nginx:lock`   | Sets up the a basic http auth on the virtual host |
| `nginx:unlock` | Removes the basic http auth                       |


### MySQL

Requires having [`mysql2`](http://rubygems.org/gems/mysql2) available in the application. In our MySQL recipe we dynamically generate a `database.yml` based on the variables that should be set globally or per-stage.

Overwritable template: [`database.yml.erb`](lib/matross/templates/mysql/database.yml.erb)

> Variables

| Variable           | Default value                          | Description                                                                     |
| ---                | ---                                    | ---                                                                             |
| `:database_config` | `"#{shared_path}/config/database.yml"` | Location of the configuration file                                              |
| `:mysql_host`      | None                                   | MySQL host address                                                              |
| `:mysql_database`  | None                                   | MySQL database name. We automatically substitute dashes `-` for underscores `_` |
| `:mysql_user`      | None                                   | MySQL user                                                                      |
| `:mysql_passwd`    | None                                   | MySQL password                                                                  |

> Tasks

| Task                | Description                                                         |
| ---                 | ---                                                                 |
| `mysql:setup`       | Creates the `database.yml` in the `shared_path`                     |
| `mysql:symlink`     | Creates a symlink for the `database.yml` file in the `current_path` |
| `mysql:create`      | Creates the database if it hasn't been created                      |
| `mysql:schema_load` | Loads the schema if there are no tables in the DB                   |

## Mongoid

Requires having [`mongoid`](http://rubygems.org/gems/mongoid) available in the application. In our Mongoid recipe we dynamically generate a `mongoid.yml` based on the variables that should be set globally or per-stage.

Overwritable template: [`mongoid.yml.erb`](lib/matross/templates/mongoid/mongoid.yml.erb)

> Variables

| Variable          | Default value                         | Description                                |
| ---               | ---                                   | ---                                        |
| `:mongoid_config` | `"#{shared_path}/config/mongoid.yml"` | Location of the mongoid configuration file |
| `:mongo_hosts`    | None                                  | **List** of MongoDB hosts                  |
| `:mongo_database` | None                                  | MongoDB database name                      |
| `:mongo_user`     | None                                  | MongoDB user                               |
| `:mongo_passwd`   | None                                  | MongoDB password                           |

> Tasks

| Task                | Description                                                        |
| ---                 | ---                                                                |
| `mongoid:setup`     | Creates the `mongoid.yml` in the `shared_path`                     |
| `mongoid:symlink`   | Creates a symlink for the `mongoid.yml` file in the `current_path` |

### Delayed Job

Requires having [`delayed_job`](http://rubygems.org/gems/delayed_job) available in the application.

Procfile task: `dj: bundle exec rake jobs:work` or `dj_<%= queue_name %>: bundle exec rake jobs:work QUEUE=<%= queue_name %>`

> Variables

| Variable     | Default value | Description    |
| ---          | ---           | ---            |
| `:dj_queues` | None          | List of queues |


> Tasks

| Task                   | Description                                                       |
| ---                    | ---                                                               |
| `delayed_job:procfile` | Defines how `delayed_job` should be run in a temporary `Procfile` |


### Fog (AWS)

Requires having [`fog`](http://rubygems.org/gems/fog) available in the application. When we use `fog`, it is for interacting with Amazon services, once again very opinionated.

Overwritable template: [`fog_config.yml.erb`](lib/matross/templates/fog/fog_config.yml.erb)

The configuration that is generated may be used by other gems, such as [`carrierwave`](http://rubygems.org/gems/carrierwave). Here is how we use it, for example:

```ruby
# config/initializers/carrierwave.rb
CarrierWave.configure do |config|
  fog_config = YAML.load(File.read(File.join(Rails.root, 'config', 'fog_config.yml')))
  config.fog_credentials = {
    :provider               => 'AWS',
    :aws_access_key_id      => fog_config['aws_access_key_id'],
    :aws_secret_access_key  => fog_config['aws_secret_access_key'],
    :region                 => fog_config['region']
  }
  config.fog_directory  = fog_config['directory']
  config.fog_public     = fog_config['public']
end
```

> Variables

| Variable                     | Default value                            | Description                            |
| ---                          | ---                                      | ---                                    |
| `:fog_config`                | `"#{shared_path}/config/fog_config.yml"` | Location of the fog configuration file |
| `:fog_region`                | `'us-east-1'`                            | AWS Region                             |
| `:fog_public`                | `false`                                  | Bucket policy                          |
| `:fog_aws_access_key_id`     | None                                     | AWS Access Key Id                      |
| `:fog_aws_secret_access_key` | None                                     | AWS Secret Access Key                  |

> Tasks

| Task          | Description                                                           |
| ---           | ---                                                                   |
| `fog:setup`   | Creates the `fog_config.yml` in the `shared_path`                     |
| `fog:symlink` | Creates a symlink for the `fog_config.yml` file in the `current_path` |

### Faye

Requires having [`faye`](http://rubygems.org/gems/faye) available in the application.

Overwritable templates: [`faye.ru.erb`](lib/matross/templates/faye/faye.ru.erb) and [`faye_server.yml`](lib/matross/templates/faye/faye_server.yml)
Procfile task: `faye: bundle exec rackup  <%= faye_ru %> -s thin -E <%= rails_env %> -p <%= faye_port %>`

> Variables

| Variable       | Default value                             | Description                                          |
| ---            | ---                                       | ---                                                  |
| `:faye_config` | `"#{shared_path}/config/faye_config.yml"` | Location of the `faye` parameters configuration file |
| `:faye_ru`     | `"#{shared_path}/config/faye.ru"`         | Location of the `faye` configuration file            |
| `:faye_port`   | None                                      | Which port `faye` should listen on                   |

> Tasks

| Task           | Description                                                            |
| ---            | ---                                                                    |
| `faye:setup`   | Creates `faye_config.yml` and `faye.ru` in the `shared_path`           |
| `faye:symlink` | Creates a symlink for the `faye_config.yml` file in the `current_path` |


### Local Assets

This recipe overwrites the default assets precompilation by compiling them locally and then uploading the result to the server.
