# app/lib/flipper_setup.rb
module FlipperSetup
  FEATURES = ["Agents", "SPARQL", "SIDEKIQ_UI", "FOOPS"].freeze

  def self.configure!
    Flipper.configure do |config|
      config.default do
        primary_adapter = Flipper::Adapters::ActiveRecord.new 

        flipper = Flipper.new(Flipper::Adapters::ActiveSupportCacheStore.new(
            primary_adapter, 
            Rails.cache, 
            10.minutes
          )
        )
        # Seed features enabled by default, without overriding those already
        # configured by an admin in the Flipper UI
        existing_features = primary_adapter.features
        FEATURES.each { |f| flipper.enable(f) unless existing_features.include?(f) }

        flipper
      end
      Flipper.register(:admins) do |actor, context|
        actor.respond_to?(:admin?) && actor.admin?
      end
    end
  end
  def self.test_configure!
    FEATURES.each { |feature| Flipper.enable(feature) }
  end
end