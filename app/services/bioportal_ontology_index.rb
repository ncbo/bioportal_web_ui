class BioportalOntologyIndex
  CACHE_KEY = "bioportal_ontology_index:v1".freeze
  CACHE_TTL = 12.hours
  LOCAL_LIST_ENV = "BIOPORTAL_ONTOLOGIES_PATH"

  def self.all
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      ontologies = fetch_all if LinkedData::Client.settings.apikey.to_s.strip.present?
      ontologies = Array(ontologies)
      ontologies = load_local_list if ontologies.empty?
      ontologies
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

  def self.load_local_list
    path = ENV[LOCAL_LIST_ENV].presence || Rails.root.join("ontologies.htm")
    return [] unless File.exist?(path)

    parse_ontologies_html(File.read(path))
  rescue StandardError => e
    Rails.logger.error("BioPortal ontology index local load failed: #{e.class}: #{e.message}")
    []
  end

  def self.parse_ontologies_html(content)
    pairs = content.scan(
      /acronym<span class="q">"<\/span><\/span>:\s*<span class="string">"([^"]+)"<\/span>.*?name<span class="q">"<\/span><\/span>:\s*<span class="string">"([^"]+)"/m
    )

    pairs.map do |acronym, name|
      { acronym: acronym, name: name }
    end.uniq { |ont| ont[:acronym] }
  end
end
