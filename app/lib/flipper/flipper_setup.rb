# app/lib/flipper_setup.rb
module FlipperSetup
  FEATURES = ["Agents", "SPARQL", "SIDEKIQ_UI"].freeze

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
        if primary_adapter.features.empty?
          FEATURES.each { |f| flipper.enable(f) }
        end

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