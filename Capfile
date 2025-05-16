# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#
# require 'capistrano/rvm'
require 'capistrano/rbenv'
# require 'capistrano/chruby'
require 'capistrano/bundler'
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git
#require 'capistrano/rails/assets'
#require 'capistrano/rails/migrations'
require 'capistrano/rails'
# locally is needed for the appliance deployments
require 'capistrano/locally'
require 'capistrano/yarn'

# announce deployments in NewRelic
require 'new_relic/recipes'
# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r } # W
