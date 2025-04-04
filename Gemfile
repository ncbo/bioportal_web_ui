# frozen_string_literal: true

source 'https://rubygems.org'

# Main Rails gem
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '7.2.2.1'

# JavaScript bundling for Rails
gem 'jsbundling-rails'

# Chart.js integration for Rails
gem 'chart-js-rails'

gem 'select2-rails'

# SassC as a replacement for sass-rails
gem 'sassc-rails' # sass-rails replacement

# Terser JavaScript minifier as a replacement for Uglifier
gem 'terser' # uglifier replacement

# Bootstrap front-end framework
gem 'bootstrap', '~> 5.2.3'

# jQuery integration for Rails
gem 'jquery-rails'

# jQuery UI integration for Rails
gem 'jquery-ui-rails'

# The original asset pipeline for Rails
# [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use the Puma web server
# [https://github.com/puma/puma]
gem 'puma', '~> 6.0'

# Use JavaScript with ESM import maps
# [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator
# [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework
# [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Debugging tool
# See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem  gem 'pry'
gem 'pry'

# Time zone info for Windows platforms
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# https://stackoverflow.com/questions/79360526/uninitialized-constant-activesupportloggerthreadsafelevellogger-nameerror
# remove pin after upgrade to rails 8.0.1+ or proper fix is implemented
gem "concurrent-ruby", "= 1.3.4"

# Memcached client for Ruby
gem 'dalli'

# GraphQL client for Ruby
# Version 2.1 breaks graphql-client. See: https://github.com/github/graphql-client/issues/310.
gem 'graphql', '~> 2.0.27'
gem 'graphql-client'

# Haml template engine for Ruby on Rails
gem 'haml', '~> 6.1.1'

# Internationalization (i18n)
gem 'i18n'
gem 'rails-i18n', '~> 7.0.0'

# MySQL database adapter
gem 'mysql2'

# JSON parsing libraries
gem 'multi_json'
gem 'oj'

# Google reCAPTCHA integration
gem 'recaptcha', '~> 5.9.0'

# Simple HTTP and REST client for Ruby
gem 'rest-client'

# View components framework for Rails
gem 'lookbook', '~> 1.5.5'

gem 'view_component', '~> 2.72'

# Pagination library for Rails
gem 'will_paginate', '~> 3.0'

# Render SVG files in Rails views
gem 'inline_svg'

# ISO language codes and flags
gem 'flag-icons-rails', '~> 3.4'
gem 'iso-639', '~> 0.3.6'

# Custom API client
gem 'ontologies_api_client', github: 'ncbo/ontologies_api_ruby_client', tag: 'v2.5.3'

gem 'rexml', '~> 3'

# Ruby 2.7.8 pinned gems (to remove when migrating to Ruby >= 3.0)
# gem 'ffi', '~> 1.16.3'
# gem 'net-ftp', '~> 0.2.0', require: false
# gem 'net-http', '~> 0.3.2'

gem 'ffi'
gem 'net-ftp', require: false
gem 'net-http'


# Multi-Provider Authentication
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'

# Additional authentication providers are not yet implemented
# gem 'omniauth-github'
# gem 'omniauth-google-oauth2'
# gem 'omniauth-keycloak'
# gem 'omniauth-orcid'

group :staging, :production, :appliance do
  # Application performance monitoring
  gem 'newrelic_rpm'

  # Error monitoring
  gem 'bugsnag', '~> 6.26'
end

group :development do
  # Capistrano Deployment
  gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0', require: false # https://github.com/miloserdow/capistrano-deploy/issues/42
  gem 'capistrano', '~> 3.17', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-locally', require: false
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-yarn', require: false
  gem 'ed25519', '>= 1.2', '< 2.0', require: false # https://github.com/miloserdow/capistrano-deploy/issues/42

  # Static code analysis
  gem 'brakeman', require: false
  gem 'rubocop', require: false

  # Haml support for Rails
  gem 'haml-rails'
  gem 'html2haml'

  # Debugging tools
  gem 'debug', platforms: %i[mri mingw x64_mingw]

  # Use console on exceptions pages
  # [https://github.com/rails/web-console]
  gem 'web-console'

  # Internationalization tasks
  # gem 'i18n-debug'
  gem 'i18n-tasks'
  gem 'i18n-tasks-csv', '~> 1.1'
  gem 'deepl-rb'

  # Email preview in the browser
  gem 'letter_opener_web', '~> 2.0'
end

group :test do
  # System testing
  # [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'

  # WebDriver for system testing
  gem 'selenium-webdriver'

  # Code coverage generation
  gem 'simplecov', require: false
  gem 'simplecov-cobertura' # for codecov.io

  # Mock HTTP requests in tests
  gem 'webmock'

  # Testing framework for Rails
  gem 'rspec-rails'
end

