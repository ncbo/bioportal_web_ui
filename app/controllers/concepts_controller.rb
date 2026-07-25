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

  # Build the ancestor is-a graph for `concept`:
  #   { root:, nodes:[{id,label,selected,hierarchyRoot}], edges:[{from,to,kind}],
  #     edge_count:, large:, truncated: }
  # The graph is the selected class plus every class reachable by walking is-a
  # (subClassOf) edges upward to the ontology root(s). Edges point child ->
  # parent (is-a). Because a class can have several parents (the hierarchy is a
  # DAG, not a tree), we walk each node's direct parents breadth-first rather
  # than using /tree, which only returns a single root-to-node path.
  def build_entity_graph_data(ontology, concept)
    root_id = concept.id
    nodes = {}
    edges = {} # dedup by "from->to"
    truncated = false

    add_node = lambda do |id, label, is_root: false|
      node = (nodes[id] ||= {
        id: id,
        label: label.presence || helpers.link_last_part(id),
        type: 'class',
        selected: is_root,
        hierarchyRoot: false # set later, once we know whether it has parents
      })
      node[:selected] = true if is_root
      node
    end

    direct_parents = lambda do |class_id|
      Array(LinkedData::Client::Models::Ontology.explore(ontology.acronym)
                                                .classes(class_id)
                                                .parents
                                                .get(display: 'prefLabel', language: request_lang))
        .reject { |p| p.respond_to?(:errors) && p.errors.present? }
    rescue StandardError
      []
    end

    add_node.call(root_id, helpers.main_language_label(concept.prefLabel), is_root: true)

    # Breadth-first walk up the parent edges. `visited` guards against re-walking
    # a shared ancestor (and against cycles).
    queue = [root_id]
    visited = {}
    until queue.empty?
      id = queue.shift
      next if visited[id]

      visited[id] = true

      if nodes.size >= ENTITY_GRAPH_MAX_NODES
        truncated = true
        break
      end

      parents = direct_parents.call(id)
      # A node with no parents is a root of the hierarchy.
      nodes[id][:hierarchyRoot] = true if nodes[id] && parents.empty?

      parents.each do |p|
        add_node.call(p.id, helpers.main_language_label(p.prefLabel))
        edges["#{id}->#{p.id}"] = { from: id, to: p.id, kind: 'is-a' } # child is-a parent
        queue << p.id unless visited[p.id]
      end
    end

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
