class BioportalOntologyIndex
  CACHE_KEY = "bioportal_ontology_index:v1".freeze
  CACHE_TTL = 12.hours

  def self.all
    return [] if LinkedData::Client.settings.apikey.to_s.strip.empty?

    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      fetch_all
    end
  end

  def self.fetch_all
    ontologies = LinkedData::Client::Models::Ontology.all(
      include: "acronym,name",
      display_links: false,
      display_context: false,
      include_views: true
    )

    Array(ontologies).filter_map do |ont|
      acronym = ont.respond_to?(:acronym) ? ont.acronym : nil
      name = ont.respond_to?(:name) ? ont.name : nil
      id = ont.respond_to?(:id) ? ont.id : nil
      next if acronym.blank?

      { acronym: acronym, name: name, id: id }
    end
  rescue StandardError => e
    Rails.logger.error("BioPortal ontology index load failed: #{e.class}: #{e.message}")
    []
  end
end
