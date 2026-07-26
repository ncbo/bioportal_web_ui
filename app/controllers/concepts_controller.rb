require 'cgi'

class ConceptsController < ApplicationController
  include MappingsHelper
  include ConceptsHelper
  include TurboHelper
  include TermsReuses

  layout 'ontology'

  def show
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => t('concepts.error_valid_concept')
      return
    end

    # Note that find_by_acronym includes views by default
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    redirect_to(ontology_path(id: params[:ontology], p: 'classes', conceptid: params[:id], lang: request_lang)) and return unless turbo_frame_request?

    @submission = get_ontology_submission_ready(@ontology)
    @concept = @ontology.explore.single_class({ full: true, language: request_lang }, params[:id])

    concept_not_found(params[:id]) if @concept.nil?
    @current_purl = @concept.purl if Rails.configuration.settings.purl[:enabled]
    @notes = @concept.explore.notes
    render partial: 'show'
  end

  def index
    # Handle multiple methods of passing concept ids
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => t('concepts.error_valid_concept')
      return
    end

    @submission = LinkedData::Client::Models::Ontology.explore(params[:ontology])
                                                      .latest_submission
                                                      .get(include: 'uriRegexPattern,preferredNamespaceUri')
    @schemes = params[:concept_schemes].split(',')

    @concept = LinkedData::Client::Models::Class.new(values: { id: params[:id] })

    @concept.children = LinkedData::Client::Models::Ontology.explore(params[:ontology])
                                                            .classes(params[:id])
                                                            .children
                                                            .get(pagesize: 750, concept_schemes: Array(@schemes).join(','), language: request_lang, display: 'prefLabel,obsolete,hasChildren').collection || []
    render turbo_stream: [
      replace(helpers.child_id(@concept) + '_open_link') { TreeLinkComponent.tree_close_icon },
      replace(helpers.child_id(@concept) + '_childs') do
        helpers.concepts_tree_component(@concept, @concept, params[:ontology], Array(@schemes), request_lang, sub_tree: true, submission: @submission)
      end
    ]
  end

  def show_label
    cls_id = params[:concept] || params[:id]
    ont_id = params[:ontology]
    pref_label = begin
                   concept_label(ont_id, cls_id)
                 rescue
                   cls_id
                 end
    cls = @ontology.explore&.single_class({ language: request_lang, include: 'prefLabel' }, cls_id)
    label = helpers.main_language_label(pref_label)
    acronym = ont_id.split("/").last
    link = concept_path(cls_id, acronym, request_lang)

    render(inline: helpers.ajax_link_chip(cls_id, label, link, external: cls.nil? || cls.errors), layout: nil)
  end

  def show_definition
    @ontology = LinkedData::Client::Models::Ontology.find(params[:ontology])
    cls = @ontology.explore.single_class(params[:concept])

    render :text => cls.definition
  end

  def show_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    @submission = @ontology.explore.latest_submission(include: 'uriRegexPattern,preferredNamespaceUri')
    if @ontology.nil? || @ontology.errors
      ontology_not_found(params[:ontology])
    else
      get_class(params, @submission)

      not_found(t('concepts.missing_roots')) if @root.nil?

      render inline: helpers.concepts_tree_component(@root, @concept,
                                                     @ontology.acronym, Array(params[:concept_schemes]&.split(',')), request_lang,
                                                     id: 'concepts_tree_view', auto_click: params[:auto_click] || true)
    end
  end

  def show_date_sorted_list
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    if @ontology.nil?
      ontology_not_found(params[:ontology])
    else
      @submission = @ontology.explore.latest_submission(include: 'uriRegexPattern,preferredNamespaceUri')
      page = params[:page]
      @last_date = params[:last_date]
      auto_click = page.to_s.eql?('1')
      params = {
        page: page,
        sortby: 'modified,created',
        order: 'desc,desc',
        display: 'prefLabel,modified,created',
        language: request_lang
      }
      if @last_date
        params.merge!(last_date: @last_date)
        @last_date = Date.parse(@last_date)
      end

      @page = @ontology.explore.classes(params)
      @concepts = filter_concept_with_no_date(@page.collection)
      @concepts_year_month = concepts_to_years_months(@concepts)

      render partial: 'concepts/date_sorted_list', locals: { auto_click: auto_click }
    end

  end

  def property_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?
    @root = @ontology.property_tree
    render json: LinkedData::Client::Models::Property.properties_to_hash(@root.children)
  end

  # Renders a details pane for a given ontology/concept
  def details
    concept_not_found(params[:conceptid]) if params[:conceptid].blank?

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, CGI.unescape(params[:conceptid]))
    concept_not_found(CGI.unescape(params[:conceptid])) if @concept.nil? || @concept.errors
    @container_id = params[:modal] ? 'application_modal_content' : 'concept_details'

    render :partial => "details"
  end

  def biomixer
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, params[:conceptid])
    concept_not_found(params[:conceptid]) if @concept.nil?

    render partial: "biomixer", layout: false
  end

  # Entity-graph data for a class: the selected class and its full is-a ancestor
  # chain up to the ontology root(s), as a node-link graph. Mirrors the
  # WebProtege entity graph (selected entity at the bottom, superclasses rising
  # to the top). Rendered into the Entity Graph tab; the graph itself is drawn
  # client-side (concept-graph Stimulus controller).
  def entity_graph
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontologyid]).first
    ontology_not_found(params[:ontologyid]) if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true, language: request_lang }, params[:conceptid])
    concept_not_found(params[:conceptid]) if @concept.nil?

    @graph = build_entity_graph_data(@ontology, @concept)
    render partial: 'entity_graph', layout: false
  end

  private

  # Past this many is-a edges the client shows a "large graph" gate rather than
  # rendering an unreadable graph (WebProtege does the same).
  ENTITY_GRAPH_LARGE_EDGE_COUNT = 200
  # Safety cap on how many ancestor classes we walk, so a pathological hierarchy
  # can't fan out into hundreds of parent lookups.
  ENTITY_GRAPH_MAX_NODES = 400
  # Relationship property labels to omit from the graph (noisy cross-cutting links
  # that pull in large unrelated cones, e.g. the taxonomic lineage).
  ENTITY_GRAPH_EXCLUDED_RELATIONS = ['in taxon'].freeze
  # Annotation property carrying "example of usage" (IAO:0000112). Shown in the
  # node hover popup when present.
  ENTITY_GRAPH_EXAMPLE_PROPERTY = 'http://purl.obolibrary.org/obo/IAO_0000112'
  # Upper ontologies whose terms are often imported as bare stubs (IRI + maybe a
  # label, no definition/examples). When such a term appears in a graph we fetch its
  # authoritative label/definition/examples from the source ontology so the popup can
  # show them (attributed to that ontology). Each entry: acronym + IRI matcher.
  # (DOLCE can be added here once it is loaded; it uses different IRIs.)
  ENTITY_GRAPH_UPPER_ONTOLOGIES = [
    { acronym: 'BFO', match: ->(iri) { iri =~ %r{[#/]BFO_\d+$} } },
    { acronym: 'COB', match: ->(iri) { iri =~ %r{[#/]COB_\d+$} } }
  ].freeze

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
    nodes = {}
    edges = {} # dedup by "from->to->label"
    truncated = false

    add_node = lambda do |id, label, is_root: false, definition: nil, examples: nil, synonyms: nil|
      node = (nodes[id] ||= {
        id: id,
        label: label.presence || helpers.link_last_part(id),
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
                                                .get(display: 'prefLabel,definition,synonym,properties', language: request_lang))
        .reject { |p| p.respond_to?(:errors) && p.errors.present? }
    rescue StandardError
      []
    end

    add_node.call(root_id, helpers.main_language_label(concept.prefLabel), is_root: true,
                  definition: first_def.call(concept), examples: class_examples.call(concept),
                  synonyms: class_synonyms.call(concept))

    add_rel_edges = lambda do |source_id|
      entity_graph_relationships(ontology, source_id).each do |rel|
        add_node.call(rel[:filler_id], rel[:filler_label], examples: rel[:filler_examples], synonyms: rel[:filler_synonyms])
        edges["#{source_id}->#{rel[:filler_id]}->#{rel[:property_id]}"] =
          { from: source_id, to: rel[:filler_id], kind: 'rel', label: rel[:property_label] }
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

        if nodes.size >= ENTITY_GRAPH_MAX_NODES
          truncated = true
          break
        end

        parents = direct_parents.call(id)
        nodes[id][:hierarchyRoot] = true if nodes[id] && parents.empty?

        parents.each do |p|
          add_node.call(p.id, helpers.main_language_label(p.prefLabel),
                        definition: first_def.call(p), examples: class_examples.call(p),
                        synonyms: class_synonyms.call(p))
          edges["#{id}->#{p.id}->is-a"] = { from: id, to: p.id, kind: 'is-a' } # child is-a parent
          queue << p.id unless visited[p.id]
        end
      end
    end

    visited = {}

    # 1) Walk the selected class's is-a spine (A ⊑ x0 ⊑ … ⊑ xn) and, for the
    #    selected class and every ancestor on it, pull that class's relationship
    #    edges (p -> B). Fillers B are added as nodes here.
    walk_ancestors.call([root_id], visited) { |id| add_rel_edges.call(id) }

    # 2) Give every relationship filler its own is-a ancestor chain, so the
    #    targets rise to the root too. Shared ancestors merge naturally. We do
    #    NOT pull relationships from the fillers themselves (only A's spine does).
    filler_seeds = nodes.keys.reject { |id| visited.key?(id) }
    walk_ancestors.call(filler_seeds, visited)

    edge_list = edges.values
    {
      root: root_id,
      nodes: nodes.values,
      edges: edge_list,
      edge_count: edge_list.size,
      truncated: truncated,
      large: edge_list.size > ENTITY_GRAPH_LARGE_EDGE_COUNT
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

    cls = begin
      ontology.explore.single_class({ full: true, language: request_lang }, class_id)
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
      predicate = predicate.to_s
      next unless object_props.key?(predicate)
      # Omit noisy cross-cutting relationships (e.g. "in taxon", which drags the
      # whole taxonomic lineage into the graph).
      next if ENTITY_GRAPH_EXCLUDED_RELATIONS.include?(object_props[predicate].to_s.strip.downcase)
      next if predicate.end_with?('RO_0002162') # in taxon

      Array(values).each do |value|
        filler = value.respond_to?(:id) ? value.id.to_s : value.to_s
        next unless filler.start_with?('http')

        filler_cls = entity_graph_filler_class(ontology, filler)
        rels << {
          property_id: predicate,
          property_label: object_props[predicate].presence || helpers.link_last_part(predicate),
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
        acc[p.id.to_s] = helpers.main_language_label(label)
      end
    rescue StandardError
      {}
    end
  end

  # Fetch a relationship filler's class (prefLabel + properties, so we can also read
  # its "example of usage"). Cached per request. Returns nil if the class can't be
  # loaded (e.g. a cross-ontology filler not present in this ontology).
  def entity_graph_filler_class(ontology, class_id)
    cache = (@entity_graph_filler_cache ||= {})
    return cache[class_id] if cache.key?(class_id)

    cache[class_id] = begin
      cls = ontology.explore.single_class({ display: 'prefLabel,synonym,properties' }, class_id)
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
    return helpers.link_last_part(class_id) if cls.nil?

    helpers.main_language_label(cls.prefLabel).presence || helpers.link_last_part(class_id)
  rescue StandardError
    helpers.link_last_part(class_id)
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
    values = props[ENTITY_GRAPH_EXAMPLE_PROPERTY.to_sym] || props[ENTITY_GRAPH_EXAMPLE_PROPERTY]
    Array(values).map do |v|
      v.to_s.sub(/\Aexample of usage:\s*/i, '').strip
    end.reject(&:blank?)
  rescue StandardError
    []
  end

  # For an upper-ontology (BFO/COB) term, fetch its AUTHORITATIVE label, definition and
  # examples from the source ontology (so a graph that only imported the bare term can
  # still show real details, attributed). Returns a hash { source:, label:, definition:,
  # examples: } or nil when the IRI isn't upper-ontology / can't be resolved. Cached
  # per request so each unique upper term is fetched at most once.
  def entity_graph_upper_info(class_id)
    onto = ENTITY_GRAPH_UPPER_ONTOLOGIES.find { |o| o[:match].call(class_id.to_s) }
    return nil if onto.nil?

    cache = (@entity_graph_upper_cache ||= {})
    return cache[class_id] if cache.key?(class_id)

    cache[class_id] = begin
      src = LinkedData::Client::Models::Ontology.find_by_acronym(onto[:acronym]).first
      cls = src && src.explore.single_class({ display: 'prefLabel,definition,synonym,properties' }, class_id)
      if cls && !(cls.respond_to?(:errors) && cls.errors.present?)
        {
          source: onto[:acronym],
          label: helpers.main_language_label(cls.prefLabel).presence,
          definition: (Array(cls.respond_to?(:definition) ? cls.definition : nil).first).presence,
          examples: entity_graph_class_examples(cls),
          synonyms: Array(cls.respond_to?(:synonym) ? cls.synonym : nil).map(&:to_s).reject(&:blank?)
        }
      end
    rescue StandardError
      nil
    end
  end

  def filter_concept_with_no_date(concepts)
    concepts.filter { |c| !concept_date(c).nil? }
  end

  def concepts_to_years_months(concepts)
    return {} if concepts.nil? || concepts.empty?

    concepts.group_by { |c| concept_date(c).year }
            .transform_values do |items|
      items.group_by { |c| concept_date(c).strftime('%B') }
    end
  end
end
