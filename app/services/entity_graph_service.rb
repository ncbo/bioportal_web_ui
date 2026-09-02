# Builds the Entity Graph data for a class: the selected class and its is-a
# ancestor chain up to the ontology root(s), plus relationship edges, as a
# node-link graph. Extracted verbatim from ConceptsController#build_entity_graph_data
# and its helpers so the graph build has a real home (and can be unit-tested and
# later reworked to fewer API calls) instead of living in the controller.
#
#   EntityGraphService.call(ontology, concept, helpers:, lang:)
#     => { root:, nodes:[{id,label,type,selected,hierarchyRoot,...}],
#          edges:[{from,to,kind,label?,prop_id?}], edge_count:, truncated:, large: }
#
# `helpers` is the view-helper proxy (for main_language_label / link_last_part) and
# `lang` is the request language — both passed in so the service stays a plain object.
class EntityGraphService < ApplicationService
  # Past this many is-a edges the client shows a "large graph" gate rather than
  # rendering an unreadable graph (WebProtege does the same).
  LARGE_EDGE_COUNT = 200
  # Safety cap on how many ancestor classes we walk, so a pathological hierarchy
  # can't fan out into hundreds of parent lookups.
  MAX_NODES = 400
  # Relationship property labels to omit from the graph (noisy cross-cutting links
  # that pull in large unrelated cones, e.g. the taxonomic lineage).
  EXCLUDED_RELATIONS = ['in taxon'].freeze
  # Max relationship fillers to pull from a SINGLE property on a SINGLE class. Some
  # properties are high-cardinality (e.g. MeSH's allowable-qualifier relations, which
  # can list 30+ fillers per heading); each filler is a separate class fetch, so
  # without a cap a handful of such classes makes the graph build hang past the
  # request timeout. A capped property is flagged so the client can note it.
  MAX_FILLERS_PER_PROPERTY = 12
  # Per-request budget on how many relationship-filler CLASSES we fetch (each is a
  # separate remote class lookup just to resolve the filler's label/examples). Past
  # this, fillers get an IRI-tail fallback label so the build can't hang on a
  # filler-dense ontology (MeSH). Common graphs need far fewer than this.
  MAX_FILLER_FETCHES = 25
  # Annotation property carrying "example of usage" (IAO:0000112). Shown in the
  # node hover popup when present.
  EXAMPLE_PROPERTY = 'http://purl.obolibrary.org/obo/IAO_0000112'
  # Upper ontologies whose terms are often imported as bare stubs (IRI + maybe a
  # label, no definition/examples). When such a term appears in a graph we fetch its
  # authoritative label/definition/examples from the source ontology so the popup can
  # show them (attributed to that ontology). Each entry: acronym + IRI matcher.
  # (DOLCE can be added here once it is loaded; it uses different IRIs.)
  UPPER_ONTOLOGIES = [
    { acronym: 'BFO', match: ->(iri) { iri =~ %r{[#/]BFO_\d+$} } },
    { acronym: 'COB', match: ->(iri) { iri =~ %r{[#/]COB_\d+$} } }
  ].freeze

  def initialize(ontology, concept, helpers:, lang:)
    @ontology = ontology
    @concept = concept
    @helpers = helpers
    @lang = lang
  end

  def call
    build_entity_graph_data(@ontology, @concept)
  end

  private

  # Ontology languages that are thesaurus/vocabulary-style rather than a real OWL/OBO
  # class hierarchy. For these, object properties are a noisy qualifier web (e.g. MeSH
  # allowable-qualifiers, SNOMED/RxNorm attributes) that swamps the graph, so we show
  # the is-a spine only. Note the dense-web ontologies (MeSH, SNOMEDCT, RxNorm) report
  # 'UMLS' here, not 'SKOS' — the property web is the same shape, so both are included.
  TAXONOMY_ONLY_LANGUAGES = %w[SKOS UMLS].freeze

  # True when the ontology's latest submission language is thesaurus-style (see above).
  # Memoized; one lightweight submission fetch. Errors default to false (treat as a real
  # OWL ontology) so a lookup hiccup never hides relationships that belong in the graph.
  def taxonomy_only_ontology?(ontology)
    return @taxonomy_only unless @taxonomy_only.nil?

    @taxonomy_only = begin
      sub = ontology.explore.latest_submission(include: 'hasOntologyLanguage')
      lang = sub && sub.hasOntologyLanguage.to_s.upcase
      lang && TAXONOMY_ONLY_LANGUAGES.include?(lang)
    rescue StandardError
      false
    end
  end

  # Build the entity graph for `concept`:
  #   { root:, nodes:[{id,label,type,selected,hierarchyRoot}],
  #     edges:[{from,to,kind,label?}], edge_count:, large:, truncated: }
  # It has two kinds of edges:
  #   * is-a edges: the selected class plus every class reachable by walking
  #     subClassOf upward to the ontology root(s). Because a class can have
  #     several parents (the hierarchy is a DAG, not a tree), we walk each node's
  #     direct parents breadth-first rather than using /tree, which only returns
  #     a single root-to-node path. Edges point child -> parent.
  #   * relationship edges: for the selected class, each asserted
  #     `SubClassOf(concept ObjectSomeValuesFrom(p B))` restriction. OntoPortal's
  #     parser materialises these as a direct triple `concept p B`, which surfaces
  #     in the class `properties`; we keep the ones whose predicate is an object
  #     property and add B as a related node. Edges point concept -> B, labelled p.
  def build_entity_graph_data(ontology, concept)
    root_id = concept.id
    # Thesaurus-style vocabularies (SKOS, and MeSH/SNOMED/RxNorm which report as UMLS)
    # model their cross-references (broader/narrower/related, MeSH's allowable-qualifier
    # and semantic-type links, …) as object properties, so pulling relationships fans out
    # into a dense, unreadable web and dozens of per-filler class fetches. For these we
    # show ONLY the is-a hierarchy — no relationship edges (and the client hides the
    # relationships filter, since the graph then carries no relationship properties).
    taxonomy_only = taxonomy_only_ontology?(ontology)
    nodes = {}
    edges = {} # dedup by "from->to->label"
    truncated = false

    add_node = lambda do |id, label, is_root: false, definition: nil, examples: nil, synonyms: nil|
      node = (nodes[id] ||= {
        id: id,
        label: label.presence || @helpers.link_last_part(id),
        type: 'class',
        selected: is_root,
        hierarchyRoot: false, # set later, once we know whether it has parents
        definition: nil,
        examples: [],
        synonyms: [],
        # `upper` holds authoritative info from the source ontology (BFO/COB) when this
        # is an upper-ontology term imported here as a stub; nil otherwise. The client
        # shows it (attributed) so imported stubs still surface a real name + definition.
        upper: nil
      })
      node[:selected] = true if is_root
      # A node can be created before its real label is known: a relationship filler
      # whose label fetch fell past MAX_FILLER_FETCHES is created with the IRI-tail
      # fallback, and its true prefLabel only arrives later — the filler is the leaf of
      # its own paths_to_root, ingested in step 2. Upgrade the placeholder when that
      # happens, the way definition/examples/synonyms already do below; otherwise the
      # node renders for good as e.g. "UBERON_0002101" instead of "limb".
      node[:label] = label if label.present? && node[:label] == @helpers.link_last_part(id)
      node[:definition] = definition if definition.present? && node[:definition].blank?
      node[:examples] = Array(examples) if Array(examples).present? && node[:examples].blank?
      node[:synonyms] = Array(synonyms) if Array(synonyms).present? && node[:synonyms].blank?
      node[:upper] = entity_graph_upper_info(id) if node[:upper].nil?
      node
    end

    first_def = ->(cls) { Array(cls.respond_to?(:definition) ? cls.definition : nil).first }
    class_examples = ->(cls) { entity_graph_class_examples(cls) }
    class_synonyms = ->(cls) { Array(cls.respond_to?(:synonym) ? cls.synonym : nil).map(&:to_s).reject(&:blank?) }

    direct_parents = lambda do |class_id|
      Array(LinkedData::Client::Models::Ontology.explore(ontology.acronym)
                                                .classes(class_id)
                                                .parents
                                                .get(display: 'prefLabel,definition,synonym,properties', language: @lang))
        .reject { |p| p.respond_to?(:errors) && p.errors.present? }
    rescue StandardError
      []
    end

    add_node.call(root_id, @helpers.main_language_label(concept.prefLabel), is_root: true,
                  definition: first_def.call(concept), examples: class_examples.call(concept),
                  synonyms: class_synonyms.call(concept))

    add_rel_edges = lambda do |source_id|
      entity_graph_relationships(ontology, source_id).each do |rel|
        add_node.call(rel[:filler_id], rel[:filler_label], examples: rel[:filler_examples], synonyms: rel[:filler_synonyms])
        edges["#{source_id}->#{rel[:filler_id]}->#{rel[:property_id]}"] =
          { from: source_id, to: rel[:filler_id], kind: 'rel', label: rel[:property_label], prop_id: rel[:property_id] }
      end
    end

    # is-a walk up from a set of seed classes, adding parent nodes + is-a edges.
    # `on_visit` runs for each class reached (used to pull that class's own
    # relationships). Returns when the queue drains or the node cap is hit.
    walk_ancestors = lambda do |seeds, visited, &on_visit|
      queue = seeds.dup
      until queue.empty?
        id = queue.shift
        next if visited[id]

        visited[id] = true
        on_visit&.call(id)

        if nodes.size >= MAX_NODES
          truncated = true
          break
        end

        parents = direct_parents.call(id)
        nodes[id][:hierarchyRoot] = true if nodes[id] && parents.empty?

        parents.each do |p|
          add_node.call(p.id, @helpers.main_language_label(p.prefLabel),
                        definition: first_def.call(p), examples: class_examples.call(p),
                        synonyms: class_synonyms.call(p))
          edges["#{id}->#{p.id}->is-a"] = { from: id, to: p.id, kind: 'is-a' } # child is-a parent
          queue << p.id unless visited[p.id]
        end
      end
    end

    visited = {}

    # 1) Build the selected class's is-a spine (A ⊑ x0 ⊑ … ⊑ xn) and, for the
    #    selected class and every ancestor on it, pull that class's relationship
    #    edges (p -> B). Fillers B are added as nodes here.
    #
    #    The spine comes from ONE `paths_to_root` call — an array of ordered
    #    root→…→A paths (the DAG's several routes to the root). Consecutive pairs in
    #    each path give the is-a edges (path[i+1] is-a path[i]); merged + deduped
    #    across all paths this reconstructs the whole is-a subgraph. Replaces the old
    #    level-by-level `.parents` BFS (one call per ancestor) with a single request.
    #    Falls back to that BFS if paths_to_root is unavailable/empty.
    #    Note: paths_to_root does not return the `properties` hash, so ordinary
    #    ancestors carry no "example of usage" (a rare, minor popup detail); BFO/COB
    #    ancestors still get examples via their authoritative upper-ontology fetch.
    # Base URL for building a class's paths_to_root endpoint from its IRI, without an
    # extra fetch: <…/ontologies/ACR/classes>/<escaped-iri>/paths_to_root. `classes`
    # is a link already on the ontology object.
    classes_base = (ontology.links && ontology.links['classes']).to_s
    paths_to_root = lambda do |class_iri|
      return [] if classes_base.empty?

      url = "#{classes_base}/#{CGI.escape(class_iri.to_s)}/paths_to_root"
      Array(LinkedData::Client::HTTP.get(url, display: 'prefLabel,definition,synonym', language: @lang))
    rescue StandardError
      []
    end

    # Add every class on a set of root→…→leaf paths as a node, plus the is-a edges
    # between consecutive path members (child -> parent). Returns the number of paths
    # ingested (0 = nothing usable, caller falls back to the BFS).
    # Ingest root→…→leaf paths: add each class as a node + the is-a edges between
    # consecutive path members. Returns the set of class ids that appeared on the paths
    # (all of them are now fully covered up to a root, so the caller can mark them
    # visited). An empty set means nothing usable — the caller falls back to the BFS.
    ingest_paths = lambda do |paths|
      seen = []
      Array(paths).each do |path|
        path = Array(path).reject { |n| n.respond_to?(:errors) && n.errors.present? }
        next if path.empty?

        path.each_with_index do |n, i|
          add_node.call(n.id, @helpers.main_language_label(n.prefLabel),
                        is_root: n.id == root_id,
                        definition: first_def.call(n),
                        synonyms: class_synonyms.call(n))
          nodes[n.id][:hierarchyRoot] = true if i.zero? && nodes[n.id] # path head = a root
          seen << n.id
          if i.positive?
            parent = path[i - 1]
            edges["#{n.id}->#{parent.id}->is-a"] = { from: n.id, to: parent.id, kind: 'is-a' }
          end
        end
      end
      seen.uniq
    end

    # Build the selected class's is-a spine from one paths_to_root call, then pull each
    # spine class's relationships. Returns false if paths_to_root gave nothing usable.
    spine_via_paths = lambda do
      return false if ingest_paths.call(paths_to_root.call(root_id)).empty?

      # every spine class: mark visited (so the Phase-2 filler walk skips it) and pull
      # its relationships, honouring the node cap. Snapshot the ids first — add_rel_edges
      # inserts filler nodes, which would otherwise mutate `nodes` mid-iteration.
      # Taxonomy-only graphs skip relationships entirely (is-a only).
      nodes.keys.each { |id| visited[id] = true }
      unless taxonomy_only
        nodes.keys.to_a.each do |id|
          if nodes.size >= MAX_NODES
            truncated = true
            break
          end
          add_rel_edges.call(id)
        end
      end
      true
    end

    unless spine_via_paths.call
      # is-a spine fallback; pull relationships per ancestor only for real ontologies.
      walk_ancestors.call([root_id], visited) { |id| add_rel_edges.call(id) unless taxonomy_only }
    end

    # 1b) Follow each relationship OUTWARD along the SAME property, transitively —
    #     e.g. `part of` chains femur → hindlimb → limb → body. We continue only the
    #     same property (A p B, then B p C, …), and only from the selected class's own
    #     chains (not from is-a ancestors' fillers), to keep the graph and the number
    #     of API calls bounded. Most chained properties in practice are transitive
    #     (part of, develops from), so the chain is usually semantically sound; a
    #     non-transitive property chained several hops is a known, accepted imprecision.
    #     Each chain follows ONE property: starting from a selected-class edge
    #     A p B, we only continue B p C, C p D, … along that same p. A different
    #     property on B is left to A's own one-hop pass (step 1); we don't cascade
    #     into it here, which is what keeps the walk bounded to the selected class's
    #     chains. `rel_seen` dedups by (source, property) so cycles terminate.
    rel_seen = {}
    follow_rel_chain = lambda do |start_id, prop_id|
      queue = [start_id]
      until queue.empty?
        break if nodes.size >= MAX_NODES

        id = queue.shift
        key = "#{id}|#{prop_id}"
        next if rel_seen[key]

        rel_seen[key] = true
        # only edges on THIS property continue the chain
        entity_graph_relationships(ontology, id).each do |rel|
          next unless rel[:property_id] == prop_id

          add_node.call(rel[:filler_id], rel[:filler_label], examples: rel[:filler_examples], synonyms: rel[:filler_synonyms])
          edges["#{id}->#{rel[:filler_id]}->#{rel[:property_id]}"] =
            { from: id, to: rel[:filler_id], kind: 'rel', label: rel[:property_label], prop_id: rel[:property_id] }
          queue << rel[:filler_id]
        end
      end
    end
    # Seed the chains from the selected class's relationship edges already created
    # in step 1 (avoids re-fetching the root), continuing each along its property.
    edges.values
         .select { |e| e[:kind] == 'rel' && e[:from] == root_id }
         .each { |e| follow_rel_chain.call(e[:to], e[:prop_id]) }

    # 2) Give every relationship filler its own is-a ancestor chain, so the targets
    #    rise to the root too. One paths_to_root call PER FILLER (not one .parents call
    #    per ancestor, which on a bushy graph like `liver` fanned out to 100+ calls) —
    #    consecutive path pairs give the is-a edges, and shared ancestors dedup through
    #    add_node/edges. We do NOT pull relationships from the fillers themselves (only
    #    the selected class's spine does). Falls back to the .parents BFS if
    #    paths_to_root is unavailable (mirroring the spine's fallback).
    filler_seeds = nodes.keys.reject { |id| visited.key?(id) }
    filler_seeds.each do |id|
      if nodes.size >= MAX_NODES
        truncated = true
        break
      end
      next if visited[id]

      visited[id] = true
      paths = paths_to_root.call(id)
      if paths.empty?
        walk_ancestors.call([id], visited) # fallback for this filler
      else
        # Mark only the classes that were ON this filler's paths (its ancestors, now
        # fully covered up to a root) as visited — so a later filler sharing them
        # doesn't re-fetch, but pending fillers NOT on these paths still get their own
        # chains walked.
        ingest_paths.call(paths).each { |nid| visited[nid] = true }
      end
    end

    edge_list = edges.values
    {
      root: root_id,
      nodes: nodes.values,
      edges: edge_list,
      edge_count: edge_list.size,
      truncated: truncated,
      large: edge_list.size > LARGE_EDGE_COUNT
    }
  end

  # Relationship edges (p -> B) asserted directly on the class `class_id` via
  # existential restrictions.
  # Returns [{property_id, property_label, filler_id, filler_label}].
  # A class `property` is a relationship iff its predicate is an object property
  # of the ontology and its value is a class IRI; annotation properties and the
  # is-a predicate (rdfs:subClassOf) are excluded.
  def entity_graph_relationships(ontology, class_id)
    object_props = ontology_object_properties(ontology) # { iri => label }
    return [] if object_props.empty?

    # Only the `properties` hash is used below (for the class's asserted relations),
    # so fetch just that — not `full: true`, which pulls the whole class payload
    # (definitions, all metadata) and, on property-dense ontologies like MeSH, drove
    # heavy allocation/GC and made the graph build hang.
    cls = begin
      ontology.explore.single_class({ display: 'properties', language: @lang }, class_id)
    rescue StandardError
      nil
    end
    return [] if cls.nil? || (cls.respond_to?(:errors) && cls.errors.present?)

    props = begin
      cls.properties.to_h
    rescue StandardError
      {}
    end

    rels = []
    props.each do |predicate, values|
      # Resolve to a canonical object-property IRI — this also recognises OBO shorthand
      # relations (part_of, has_part, …) that arrive in the …/metadata/obo/ namespace
      # and would otherwise be dropped. nil means it isn't an object property.
      prop_iri = entity_graph_resolve_property(ontology, predicate.to_s)
      next if prop_iri.nil?

      # Omit noisy cross-cutting relationships (e.g. "in taxon", which drags the
      # whole taxonomic lineage into the graph).
      next if EXCLUDED_RELATIONS.include?(object_props[prop_iri].to_s.strip.downcase)
      next if prop_iri.end_with?('RO_0002162') # in taxon

      # Only http-valued fillers are classes; cap how many we fetch per property so a
      # high-cardinality relation on one class can't fan out into dozens of sequential
      # class fetches (the MeSH allowable-qualifier case that hung the endpoint).
      http_values = Array(values).select do |value|
        (value.respond_to?(:id) ? value.id.to_s : value.to_s).start_with?('http')
      end
      http_values.first(MAX_FILLERS_PER_PROPERTY).each do |value|
        filler = value.respond_to?(:id) ? value.id.to_s : value.to_s

        filler_cls = entity_graph_filler_class(ontology, filler)
        rels << {
          property_id: prop_iri,
          property_label: object_props[prop_iri].presence || @helpers.link_last_part(prop_iri),
          filler_id: filler,
          filler_label: entity_graph_class_label(ontology, filler, filler_cls),
          filler_examples: entity_graph_class_examples(filler_cls),
          filler_synonyms: (filler_cls && Array(filler_cls.respond_to?(:synonym) ? filler_cls.synonym : nil).map(&:to_s).reject(&:blank?)) || []
        }
      end
    end
    rels
  end

  # Map of { object_property_iri => label } for the ontology, built from its
  # property tree. Memoised per request.
  def ontology_object_properties(ontology)
    @ontology_object_properties ||= begin
      root = ontology.property_tree
      flat = []
      collect = lambda do |nodes|
        Array(nodes).each do |n|
          flat << n
          collect.call(n.children) if n.respond_to?(:children) && n.children
        end
      end
      collect.call(root.respond_to?(:children) ? root.children : root)

      flat.each_with_object({}) do |p, acc|
        type = (p.respond_to?(:type) ? p.type : nil) || p.instance_variable_get(:@type)
        next unless type.to_s.include?('ObjectProperty')

        label = p.respond_to?(:label) ? Array(p.label).first : nil
        label ||= (p.respond_to?(:prefLabel) ? p.prefLabel : nil)
        acc[p.id.to_s] = @helpers.main_language_label(label)
      end
    rescue StandardError
      {}
    end
  end

  # Resolve a raw property predicate (as it appears in a class's `properties`) to a
  # canonical object-property IRI, or nil if it isn't one of the ontology's object
  # properties. Most predicates already arrive as the canonical IRI (e.g. the RO_*
  # relations). OBO shorthand relations, though, come back in BioPortal's metadata
  # namespace with the shorthand as the last segment — e.g. `part of` arrives as
  # `…/metadata/obo/part_of`, not `…/obo/BFO_0000050`. Map those back by matching the
  # shorthand against the object properties' slugged labels (`part of` -> `part_of`),
  # so partonomy relations aren't silently dropped.
  def entity_graph_resolve_property(ontology, predicate)
    op = ontology_object_properties(ontology)
    return predicate if op.key?(predicate)

    m = predicate.match(%r{/metadata/obo/([^/]+)\z})
    return nil unless m

    shorthand = m[1]
    (@entity_graph_prop_by_slug ||= op.each_with_object({}) do |(iri, label), acc|
      slug = label.to_s.strip.downcase.gsub(/\s+/, '_')
      acc[slug] ||= iri
    end)[shorthand.downcase]
  end

  # Fetch a relationship filler's class (prefLabel + properties, so we can also read
  # its "example of usage"). Cached per request. Returns nil if the class can't be
  # loaded, OR once the per-request fetch budget is spent — each filler is a separate
  # remote class fetch, and on filler-dense ontologies (MeSH) that adds up to the
  # graph build timing out. Past the budget, callers fall back to the IRI-tail label
  # (and skip filler examples), so the graph still builds. Common graphs stay well
  # under the budget and are fully resolved.
  def entity_graph_filler_class(ontology, class_id)
    cache = (@entity_graph_filler_cache ||= {})
    return cache[class_id] if cache.key?(class_id)

    @entity_graph_filler_fetches ||= 0
    return nil if @entity_graph_filler_fetches >= MAX_FILLER_FETCHES

    @entity_graph_filler_fetches += 1
    cache[class_id] = begin
      # Label + synonyms only, NOT properties: `properties` is the heavy field on
      # filler-dense ontologies and is only needed here for a filler's example-of-
      # usage — a minor tooltip detail on relationship-target nodes. Dropping it
      # trims each filler fetch's payload; the selected class and its spine still
      # carry examples (fetched separately).
      cls = ontology.explore.single_class({ display: 'prefLabel,synonym' }, class_id)
      cls && !(cls.respond_to?(:errors) && cls.errors.present?) ? cls : nil
    rescue StandardError
      nil
    end
  end

  # Resolve a filler class's label. Falls back to the IRI's last segment when the
  # class is not in this ontology (e.g. a cross-ontology filler like NCBITaxon).
  # `cls` may be passed in to avoid a second fetch.
  def entity_graph_class_label(ontology, class_id, cls = nil)
    cls ||= entity_graph_filler_class(ontology, class_id)
    return @helpers.link_last_part(class_id) if cls.nil?

    @helpers.main_language_label(cls.prefLabel).presence || @helpers.link_last_part(class_id)
  rescue StandardError
    @helpers.link_last_part(class_id)
  end

  # "example of usage" (IAO:0000112) values from a class's properties hash. The
  # OBO->OWL conversion often prefixes each value with "example of usage: " — strip
  # it. Returns [] when the class is nil or carries no examples.
  def entity_graph_class_examples(cls)
    return [] if cls.nil?

    props = (cls.respond_to?(:properties) ? cls.properties : nil)
    props = (props.respond_to?(:to_h) ? props.to_h : props) || {}
    # properties come back as an OpenStruct-derived hash whose keys are SYMBOLS
    # (e.g. :"http://…/IAO_0000112"), so look the property up by both symbol and string.
    values = props[EXAMPLE_PROPERTY.to_sym] || props[EXAMPLE_PROPERTY]
    Array(values).map do |v|
      v.to_s.sub(/\Aexample of usage:\s*/i, '').strip
    end.reject(&:blank?)
  rescue StandardError
    []
  end

  # The source ontology record for an upper ontology, memoised per acronym.
  # find_by_acronym is an uncached HTTP GET, so without this a graph carrying N
  # BFO terms fetched /ontologies/BFO N times (measured: 8x on a UBERON class).
  def upper_ontology_source(acronym)
    @upper_ontology_source ||= {}
    @upper_ontology_source.fetch(acronym) do
      @upper_ontology_source[acronym] = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    end
  end

  # For an upper-ontology (BFO/COB) term, fetch its AUTHORITATIVE label, definition and
  # examples from the source ontology (so a graph that only imported the bare term can
  # still show real details, attributed). Returns a hash { source:, label:, definition:,
  # examples: } or nil when the IRI isn't upper-ontology / can't be resolved. Cached
  # per request so each unique upper term is fetched at most once.
  def entity_graph_upper_info(class_id)
    onto = UPPER_ONTOLOGIES.find { |o| o[:match].call(class_id.to_s) }
    return nil if onto.nil?

    cache = (@entity_graph_upper_cache ||= {})
    return cache[class_id] if cache.key?(class_id)

    cache[class_id] = begin
      src = upper_ontology_source(onto[:acronym])
      cls = src && src.explore.single_class({ display: 'prefLabel,definition,synonym,properties' }, class_id)
      if cls && !(cls.respond_to?(:errors) && cls.errors.present?)
        {
          source: onto[:acronym],
          label: @helpers.main_language_label(cls.prefLabel).presence,
          definition: (Array(cls.respond_to?(:definition) ? cls.definition : nil).first).presence,
          examples: entity_graph_class_examples(cls),
          synonyms: Array(cls.respond_to?(:synonym) ? cls.synonym : nil).map(&:to_s).reject(&:blank?)
        }
      end
    rescue StandardError
      nil
    end
  end
end
