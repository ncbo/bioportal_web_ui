require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BioportalWebUi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.active_record.yaml_column_permitted_classes = [
      ActionController::Parameters,
      HashWithIndifferentAccess
    ]

    # permitted locales available for the application
    config.i18n.available_locales = [:en, :fr, :it, :de]
    config.i18n.default_locale = :en


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.exceptions_app = self.routes



    config.settings = config_for :settings
    # Initialize configuration for KGCL change request functionality.
    config.change_request = config_for :change_request

    config.generators.template_engine = :haml
    config.generators.test_framework  =  nil

    # Set the default layout to app/views/layouts/component_preview.html.erb
    config.view_component.default_preview_layout = "component_preview"
  end
end
