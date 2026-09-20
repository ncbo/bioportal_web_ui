require "yaml"

class KgOntologyMapper
  MAPPING_FILE = Rails.root.join("config", "kg_registry_mapping.yml").freeze

  def self.sources_from(kg)
    products = Array(kg[:products]).compact
    sources = products.flat_map do |product|
      Array(product[:original_source]) + Array(product[:secondary_source])
    end
    sources.compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
  end

  def self.map_sources(sources, skip_lookup: false)
    sources = Array(sources).compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
    return empty_result(sources) if sources.empty?
    return empty_result(sources) if skip_lookup

    ontologies = BioportalOntologyIndex.all
    return { sources: sources, mappings: [], ontologies: [], unmapped: sources, unavailable: true } if ontologies.empty?

    alias_map = load_aliases
    index = build_index(ontologies)

    mappings = []
    unmapped = []

    sources.each do |source|
      matches = resolve_source(source, alias_map, index)
      if matches.empty?
        unmapped << source
      else
        mappings << { source: source, ontologies: matches }
      end
    end

    {
      sources: sources,
      mappings: mappings,
      ontologies: mappings.flat_map { |m| m[:ontologies] }.uniq { |ont| ont[:acronym] },
      unmapped: unmapped,
      unavailable: false
    }
  end

  def self.empty_result(sources)
    { sources: sources, mappings: [], ontologies: [], unmapped: [], unavailable: false }
  end

  def self.load_aliases
    return {} unless File.exist?(MAPPING_FILE)

    data = YAML.safe_load(File.read(MAPPING_FILE), aliases: false) || {}
    aliases = data["aliases"] || {}
    aliases.each_with_object({}) do |(key, value), acc|
      acc[key.to_s.downcase] = value
    end
  rescue StandardError => e
    Rails.logger.error("KG mapping load failed: #{e.class}: #{e.message}")
    {}
  end

  def self.build_index(ontologies)
    acronym_index = {}
    normalized_index = {}

    ontologies.each do |ont|
      acronym = ont[:acronym].to_s
      name = ont[:name].to_s
      next if acronym.empty?

      acronym_index[acronym.downcase] = ont
      normalized_index[normalize(acronym)] ||= ont
      normalized_index[normalize(name)] ||= ont unless name.empty?
    end

    { acronym: acronym_index, normalized: normalized_index }
  end

  def self.resolve_source(source, alias_map, index)
    source_key = source.to_s.strip
    return [] if source_key.empty?

    mapped = alias_map[source_key.downcase] || alias_map[normalize(source_key)]
    acronyms = Array(mapped.presence || source_key)

    acronyms.filter_map do |acronym|
      key = acronym.to_s
      next if key.empty?

      index[:acronym][key.downcase] || index[:normalized][normalize(key)]
    end.uniq { |ont| ont[:acronym] }
  end

  def self.normalize(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
  end
end
