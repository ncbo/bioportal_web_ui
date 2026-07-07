require Rails.root.join('app/lib/flipper/flipper_setup')

Flipper::UI.configure do |config|
  env = Rails.env.presence || ENV["RAILS_ENV"].presence || "development"
  env_display_map = {
    "appliance" => "Production",
    "development" => "Development"
  }
  env_class_map = {
    "appliance" => "danger",
    "development" => "info",
  }

  config.banner_text = "#{env_display_map[env] || env.titleize} Environment"
  config.banner_class = env_class_map[env] || "secondary"

  # Feature descriptions
  config.descriptions_source = ->(keys) do
    {
      "SPARQL" => "Enables the SPARQL endpoint feature. Requires SPARQL_ENDPOINT_URL environment variable to be configured.",
      "FOOPS" => "Enables the FOOPS! FAIRness assessment on the ontology summary page. Requires the FOOPS_URL environment variable (defaults to the public FOOPS! service)."
    }
  end

  # Show feature descriptions on the list page as well as the view page
  config.show_feature_description_in_list = true
end

FlipperSetup.configure!