# frozen_string_literal: true

source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '7.0.8'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails', require: 'sprockets/railtie'

# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem 'jsbundling-rails', '~> 1.3'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem 'jbuilder'

# Use Redis for Action Cable
gem 'redis', '~> 4.0'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem 'kredis'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
gem 'dartsass-rails', '~> 0.5.0'

gem 'bootstrap', '~> 5.2.3'
gem 'chart-js-rails'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'select2-rails'

gem 'base64', '0.1.0'
gem 'cube-ruby', require: 'cube'
gem 'dalli'
gem 'flamegraph'
# Version 2.1 breaks graphql-client. See: https://github.com/github/graphql-client/issues/310.
gem 'graphql', '~> 2.0.27'
gem 'graphql-client'
gem 'haml', '~> 5.1'
gem 'i18n'
gem 'iconv'
gem 'multi_json'
gem 'mysql2', '0.5.5'
gem 'oj'
gem 'ontologies_api_client', github: 'ncbo/ontologies_api_ruby_client', tag: 'v2.2.5'
gem 'open_uri_redirections'
gem 'pry'
gem 'psych', '< 4'
gem 'rack-mini-profiler'
gem 'rails_autolink'
gem 'rdoc'
gem 'recaptcha', '~> 5.9.0'
gem 'rest-client'
gem 'rexml', '~> 3'
gem 'stackprof', require: false
gem 'terser'
gem 'thin'
gem 'will_paginate', '~> 3.0'

group :staging, :production do
  # Application monitoring
  gem 'newrelic_rpm'
  # Logs in json format, useful for shipping logs to logstash
  # gem 'rackstash', git: 'https://github.com/planio-gmbh/rackstash.git'
  # gem 'logstash-logger'
end

group :development do
  # Capistrano deployment
  gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0', require: false # https://github.com/miloserdow/capistrano-deploy/issues/42
  gem 'capistrano', '~> 3.17', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-locally', require: false
  gem 'capistrano-passenger', require: false
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-yarn', require: false
  gem 'ed25519', '>= 1.2', '< 2.0', require: false # https://github.com/miloserdow/capistrano-deploy/issues/42
  gem 'html2haml'
  gem 'listen'

  # Static code analysis
  gem 'brakeman', require: false
  gem 'rubocop', require: false

  # gem 'i18n-debug'
end

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'rspec-rails'
end

group :test do
  gem 'capybara'
end
