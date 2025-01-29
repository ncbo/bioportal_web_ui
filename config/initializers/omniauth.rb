Rails.application.config.middleware.use OmniAuth::Builder do
  Array($OMNIAUTH_PROVIDERS).each do |provider, config|
    provider config[:strategy] || provider, config[:client_id], config[:client_secret], client_options: {}.merge(config[:client_options].to_h)
  end
end