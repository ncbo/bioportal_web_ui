require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  config.assets.debug = true
  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.action_mailer.delivery_method = :letter_opener_web

  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: '0.0.0:3000' } # Adjust the host/port as needed

  config.action_mailer_letter_opener_location = Rails.root.join('tmp', 'my_mails')

  
  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true
  
   # Allow all hosts in development
   config.hosts = nil
  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # memcache setup
  config.cache_store = :mem_cache_store, ENV['MEMCACHE_SERVERS'] || 'localhost', { namespace: 'BioPortal' }

  # Silence cache output
  config.cache_store.logger = Logger.new("/dev/null") if config.cache_store.respond_to?(:logger)

  # Add custom data attributes to sanitize allowed list
  config.action_view.sanitized_allowed_attributes = ['id', 'class', 'style', 'data-cls', 'data-ont']
  config.view_component.generate.sidecar = true

  config.file_watcher = ActiveSupport::FileUpdateChecker

  # Include BioPortal-specific configuration options
  require Rails.root.join('config', "bioportal_config_#{Rails.env}.rb")

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true
end
