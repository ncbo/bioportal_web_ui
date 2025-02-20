set :author, "ncbo"
set :application, "bioportal_web_ui"

set :repo_url, "https://github.com/#{fetch(:author)}/#{fetch(:application)}.git"

set :deploy_via, :remote_cache
# set :deploy_via, :copy

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# default deployment branch is master wich can be overwritten with BRANCH env var
# BRANCH env var can be set to specific branch of tag, i.e 'v6.8.1'

set :branch, ENV.include?('BRANCH') ? ENV['BRANCH'] : 'master'

# Default deploy_to directory is /var/www/my_app
set :deploy_to, "/opt/ontoportal/#{fetch(:application)}"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :error

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{tmp/restart.txt}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache public/system public/assets config/locales}
set :linked_dirs, %w{log tmp/pids tmp/cache public/system public/assets}
# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5
set :bundle_without, 'development:test'
set :bundle_config, { deployment: true }

# Defaults to [:web]
set :assets_roles, [:web, :app]
set :keep_assets, 3

# If you want to restart using `touch tmp/restart.txt`, add this to your config/deploy.rb:
# set :passenger_restart_with_touch, true

# If you want to restart using `passenger-config restart-app`, add this to your config/deploy.rb:
# set :passenger_restart_with_touch, false # Note that `nil` is NOT the same as `false` here
# If you don't set `:passenger_restart_with_touch`, capistrano-passenger will check what version of passenger you are running
# and use `passenger-config restart-app` if it is available in that version.

# rbenv ruby version
set :rbenv_type, :system
set :rbenv_ruby, File.read('.ruby-version').strip

desc "Check if agent forwarding is working"
task :forwarding do
  on roles(:all) do |h|
    if test("env | grep SSH_AUTH_SOCK")
      info "Agent forwarding is up to #{h}"
    else
      error "Agent forwarding is NOT up to #{h}"
    end
  end
end

namespace :deploy do
  desc 'display remote system env vars'
  task :show_remote_env do
    on roles(:all) do
      remote_env = capture("env")
      puts remote_env
    end
  end

  desc 'Incorporate the bioportal_conf private repository content'
  # Get cofiguration from repo if PRIVATE_CONFIG_REPO env var is set
  # or get config from local directory if LOCAL_CONFIG_PATH env var is set
  task :get_config do
    if defined?(PRIVATE_CONFIG_REPO)
      TMP_CONFIG_PATH = "/tmp/#{SecureRandom.hex(15)}".freeze
      on roles(:app) do
        execute "git clone -q #{PRIVATE_CONFIG_REPO} #{TMP_CONFIG_PATH}"
        execute "rsync -a #{TMP_CONFIG_PATH}/#{fetch(:application)}/ #{release_path}/"
        execute "rm -rf #{TMP_CONFIG_PATH}"
      end
    elsif defined?(LOCAL_CONFIG_PATH)
      on roles(:app) do
        execute "rsync -a #{LOCAL_CONFIG_PATH}/#{fetch(:application)}/ #{release_path}/"
      end
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute 'sudo /bin/systemctl restart ui.service'
    end
  end

  after :updating, :get_config
  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:app), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end
