# Load the Rails application.
require_relative 'application'


# Remove this after migrating to Rails 7.1 (https://github.com/rails/rails/issues/32947#issuecomment-1356391185)
class Rails::Application
  def secret_key_base
    if Rails.env.development? || Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"]
      secrets.secret_key_base ||= generate_development_secret
    else
      validate_secret_key_base(
        ENV["SECRET_KEY_BASE"] || credentials.secret_key_base || secrets.secret_key_base
      )
    end
  end
end

# Initialize the Rails application.
Rails.application.initialize!
