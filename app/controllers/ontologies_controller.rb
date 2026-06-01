class OntologiesController < ApplicationController
  include MappingsHelper
  include FairScoreHelper
  include InstancesHelper
  include ActionView::Helpers::NumberHelper
  include OntologiesHelper
  include ConceptsHelper
  include SchemesHelper
  include CollectionsHelper
  include MappingStatistics
  include OntologyUpdater
  include TurboHelper
  include SparqlHelper
  include SubmissionFilter
  include OntologyContentSerializer
  include UriRedirection
  include PropertiesHelper

  require 'multi_json'
  require 'cgi'

  helper :concepts
  helper :fair_score

  layout 'ontology'

  before_action :authorize_and_redirect, :only => [:create, :new]
  before_action :submission_metadata, only: [:show]
  before_action :set_federated_portals, only: [:index, :ontologies_filter]
  before_action :authorize_read_only, :only => [:new, :create, :edit, :update, :destroy]
  before_action :authorize_ontology_admin, only: [:edit]

  KNOWN_PAGES = Set.new(["terms", "classes", "mappings", "notes", "widgets", "summary", "properties", "instances", "schemes", "collections", "sparql"])
  EXTERNAL_MAPPINGS_GRAPH = "http://data.bioontology.org/metadata/ExternalMappings"
  INTERPORTAL_MAPPINGS_GRAPH = "http://data.bioontology.org/metadata/InterportalMappings"

  # GET /ontologies
  def index
    @categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    @groups = LinkedData::Client::Models::Group.all(display_links: false, display_context: false)

    @filters = ontology_filters_init(@categories, @groups)
    render 'ontologies/browser/browse'
  end

  def ontologies_filter
    @time = Benchmark.realtime do
      @ontologies, @count, @count_objects, @request_params, @federation_counts = submissions_paginate_filter(params)
    end

    if @page.page.eql?(1)
      streams = [prepend("ontologies_list_view-page-#{@page.page}", partial: 'ontologies/browser/ontologies')]

      streams += @count_objects.map do |section, values_count|
        values_count.map do |value, count|
          replace("count_#{section}_#{link_last_part(value)}") do
            helpers.turbo_frame_tag("count_#{section}_#{link_last_part(value)}") do
            helpers.content_tag(:span, count.to_s, class: "hide-if-loading #{count.zero? ? 'disabled' : ''}")
            end
          end
        end
      end.flatten

      if federated_request?
        streams += [
          replace('categories_refresh_for_federation') do
            key = 'categories'
            objects, checked_values, _ = @filters[key.to_sym]
            objects = keep_only_root_categories(objects)

            helpers.browse_filter_section_body(checked_values: checked_values,
                                               key: key, objects: objects,
                                               counts: @count_objects[key.to_sym])
          end
        ]
      end

    else
      streams = [replace("ontologies_list_view-page-#{@page.page}", partial: 'ontologies/browser/ontologies')]
    end

    render turbo_stream: streams
  end

  def classes
    @submission = get_ontology_submission_ready(@ontology)
    get_class(params)

    if @submission.hasOntologyLanguage == 'SKOS'
      @schemes = get_schemes(@ontology)
      @collections = get_collections(@ontology, add_colors: true)
    else
      @instance_details, type = get_instance_and_type(params[:instanceid])
      unless @instance_details.empty? || type.nil? || concept_id_param_exist?(params)
        params[:conceptid] = type # set class id from the type of the specified instance id
      end
      @instances_concept_id = get_concept_id(params, @concept, @root)
    end

    if ['application/ld+json', 'application/json'].include?(request.accept)
      render plain: @concept.to_jsonld, content_type: request.accept and return
    end

    @current_purl = @concept.purl if $PURL_ENABLED

    unless @concept.nil? || @concept.id == 'bp_fake_root'
      @notes = @concept.explore.notes
    end

    if request.xhr?
      render 'ontologies/sections/visualize', layout: false
    else
      render 'ontologies/sections/visualize', layout: 'ontology_viewer'
    end
  end

  def properties
    @acronym = @ontology.acronym
    @properties = LinkedData::Client::HTTP.get("/ontologies/#{@acronym}/properties/roots", { lang: request_lang })
    @property = get_property(params[:propertyid] || @properties.first.id,  @acronym, include: 'all') unless @property || @properties.empty?

    if request.xhr?
      render 'ontologies/sections/properties', layout: false
    else
      render 'ontologies/sections/properties', layout: 'ontology_viewer'
    end
  end

  def create
    @is_update_ontology = false
    @ontology = ontology_from_params.save

    if response_error?(@ontology)
      show_new_errors(@ontology)
      return
    end

    @submission = save_submission(new_submission_hash(@ontology))

    if response_error?(@submission)
      @ontology.delete
      show_new_errors(@submission)
    else
      redirect_to "/ontologies/success/#{@ontology.acronym}"
    end
  end

  def edit
    submission = @ontology.explore.latest_submission(include: 'submissionId')
    if submission
      redirect_to edit_ontology_submission_path(@ontology.acronym, submission.submissionId)
    else
      redirect_to new_ontology_submission_path(@ontology.acronym)
    end
  end

  def mappings
    @ontology_acronym = @ontology.acronym || params[:id]
    @mapping_counts = mapping_counts(@ontology_acronym)
    @ontologies_mapping_count = LinkedData::Client::HTTP.get("#{MAPPINGS_URL}/statistics/ontologies")
    if request.xhr?
      render partial: 'ontologies/sections/mappings', layout: false
    else
      render partial: 'ontologies/sections/mappings', layout: 'ontology_viewer'
    end
  end

  def new
    @ontology = LinkedData::Client::Models::Ontology.new
    @ontology.viewOf = params.dig(:ontology, :viewOf)
    @submission = LinkedData::Client::Models::OntologySubmission.new
    @submission.hasOntologyLanguage = 'OWL'
    @submission.released = Date.today.to_s
    @submission.status = 'production'
    @ontologies = LinkedData::Client::Models::Ontology.all(include: 'acronym', include_views: true, display_links: false, display_context: false)
    @categories = LinkedData::Client::Models::Category.all
    @groups = LinkedData::Client::Models::Group.all
    @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
    @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
  end

  def notes
    @notes = @ontology.explore.notes
    @notes_deletable = false
    # TODO_REV: Handle notes deletion
    # @notes.each {|n| @notes_deletable = true if n.deletable?(session[:user])} if @notes.kind_of?(Array)
    @note_link = "/ontologies/#{@ontology.acronym}/notes/"
    if request.xhr?
      render partial: 'ontologies/sections/notes', layout: false
    else
      render partial: 'ontologies/sections/notes', layout: 'ontology_viewer'
    end
  end

  def instances

    params[:instanceid] = params[:instanceid] || search_first_instance_id

    if params[:instanceid]
      @instance = helpers.get_instance_details_json(@ontology.acronym, params[:instanceid], {include: 'all'})
    end

    render partial: 'instances/instances', locals: { id: 'instances-data-table' }, layout: 'ontology_viewer'
  end

  def schemes
    @schemes = get_schemes(@ontology)
    scheme_id = params[:schemeid] || @submission_latest.URI || nil
    @scheme = scheme_id ? get_scheme(@ontology, scheme_id) : @schemes.first


    render partial: 'ontologies/sections/schemes', layout: 'ontology_viewer'
  end

  def collections
    @collections = get_collections(@ontology)
    collection_id = params[:collectionid]
    @collection = collection_id ? get_collection(@ontology, collection_id) : @collections.first

    render partial: 'ontologies/sections/collections', layout: 'ontology_viewer'
  end

  def sparql
    @sparql_submission = latest_rdf_submission(@ontology) || @submission_latest
    if request.xhr?
      render partial: 'ontologies/sections/sparql', layout: false
    else
      render partial: 'ontologies/sections/sparql', layout: 'ontology_viewer'
    end
  end

  def content_serializer
    @result, _ = serialize_content(ontology_acronym: params[:acronym],
                      concept_id: params[:id],
                      format: params[:output_format])

    render 'ontologies/content_serializer', layout: nil
  end

  # GET /ontologies/ACRONYM
  # GET /ontologies/1.xml
  def show
    return redirect_to_file if redirect_to_file?

    # Hack to make ontologyid and conceptid work in addition to id and ontology params
    params[:id] = params[:id].nil? ? params[:ontologyid] : params[:id]
    params[:ontology] = params[:ontology].nil? ? params[:id] : params[:ontology]

    # Hash to convert Lexvo URI to flag code

    # PURL-specific redirect to handle /ontologies/{ACR}/{CLASS_ID} paths
    if params[:purl_conceptid]
      params[:purl_conceptid] = 'root' if params[:purl_conceptid].eql?('classes')
      if params[:conceptid]
        params.delete(:purl_conceptid)
      else
        params[:conceptid] = params.delete(:purl_conceptid)
      end
      redirect_to "/ontologies/#{params[:acronym]}?p=classes&conceptid=#{params[:conceptid]}", status: :moved_permanently
      return
    end

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first

    if @ontology.nil? || @ontology.errors
      if ontology_access_denied?
        redirect_to "/login?redirect=/ontologies/#{params[:ontology]}", alert: t('login.private_ontology')
        return
      else
        ontology_not_found(params[:ontology])
      end
    end

    # Handle the case where an ontology is converted to summary only.
    # See: https://github.com/ncbo/bioportal_web_ui/issues/133.
    data_pages = KNOWN_PAGES - %w[summary notes]
    if @ontology.summaryOnly && params[:p].present? && data_pages.include?(params[:p].to_s)
      params[:p] = "summary"
    end


    # Get the latest submission (not necessarily the latest 'ready' submission)

    @submission_latest = @ontology.explore.latest_submission(include: 'all', invalidate_cache: invalidate_cache?) rescue @ontology.explore.latest_submission(include: '')


    unless helpers.submission_ready?(@submission_latest)
      @ontology_submissions = @ontology.explore.submissions(include: 'submissionId,submissionStatus')
      if @ontology_submissions.any?{|x| helpers.submission_ready?(x)}
        @old_submission_ready = true
      elsif !params[:p].blank?
        params[:p] = "summary"
      end
    end

    # Is the ontology downloadable?
    @ont_restricted = ontology_restricted?(@ontology.acronym)

    # Fix parameters to only use known pages
    params[:p] = nil unless KNOWN_PAGES.include?(params[:p])

    # This action is now a router using the 'p' parameter as the page to show
    case params[:p]
    when 'classes'
      self.classes # rescue self.summary
    when 'mappings'
      self.mappings # rescue self.summary
    when 'notes'
      self.notes # rescue self.summary
    when 'widgets'
      self.widgets # rescue self.summary
    when 'properties'
      self.properties # rescue self.summary
    when 'summary'
      self.summary
    when 'instances'
      self.instances
    when 'schemes'
      self.schemes
    when 'collections'
      self.collections
    when 'sparql'
      self.sparql
    else
      self.summary
    end
  end

  def submit_success
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    render 'submit_success'
  end


  # Main ontology description page (with metadata): /ontologies/ACRONYM
  def summary

    @metrics = @ontology.explore.metrics rescue []
    #@reviews = @ontology.explore.reviews.sort {|a,b| b.created <=> a.created} || []
    @projects = @ontology.explore.projects.sort { |a, b| a.name.downcase <=> b.name.downcase } || []
    @analytics = LinkedData::Client::HTTP.get(@ontology.links['analytics'])

    # Call to fairness assessment service
    tmp = fairness_service_enabled? ? get_fair_score(@ontology.acronym) : nil
    @fair_scores_data = create_fair_scores_data(tmp.values.first) unless tmp.nil?

    @views = get_views(@ontology)
    @view_decorators = @views.map { |view| ViewDecorator.new(view, view_context) }
    @ontology_relations_data = ontology_relations_data
    @relations_array_display = @relations_array.map do |relation|
      attr = relation.split(':').last
      ["#{helpers.attr_label(attr, attr_metadata: helpers.attr_metadata(attr), show_tooltip: false)}(#{relation})",
       relation]
    end
    @relations_array_display.unshift(['View of (bpm:viewOf)', 'bpm:viewOf'])

    category_attributes = submission_metadata.group_by { |x| x['category'] }.transform_values { |x| x.map { |attr| attr['attribute'] } }

    @config_properties = properties_hash_values(category_attributes["object description properties"])
    @methodology_properties = properties_hash_values(category_attributes["methodology"])
    @agents_properties = properties_hash_values(category_attributes['agents'])
    @dates_properties = properties_hash_values(category_attributes["dates"])
    @links_properties = properties_hash_values([:isFormatOf, :hasFormat, :source, :includedInDataCatalog])
    @content_properties = properties_hash_values(category_attributes["content"])
    @community_properties = properties_hash_values(category_attributes["community"] + [:notes])
    @identifiers = properties_hash_values([:URI, :versionIRI, :identifier])
    @identifiers["ontology_portal_uri"] = ["#{$UI_URL}/ontologies/#{@ontology.acronym}", "#{portal_name} URI"]
    @projects_properties = properties_hash_values(category_attributes["usage"] - ["hasDomain"])
    @ontology_icon_links = [%w[summary/download dataDump],
                            %w[summary/homepage homepage],
                            %w[summary/documentation documentation],
                            %w[icons/github repository],
                            %w[summary/sparql endpoint],
                            %w[icons/publication publication],
                            %w[icons/searching_database openSearchDescription]
    ]
    @ontology_icon_links.each do |icon|
      icon << helpers.attr_label(icon[1], attr_metadata: helpers.attr_metadata(icon[1]), show_tooltip: false)
    end
    if request.xhr?
      render partial: 'ontologies/sections/metadata', layout: false
    else
      render partial: 'ontologies/sections/metadata', layout: 'ontology_viewer'
    end
  end

  def subscriptions
    ontology_id = params[:ontology_id]
    return not_found if ontology_id.nil?

    ontology_acronym = ontology_id.split('/').last

    if session[:user].nil?
      link = "/login?redirect=/ontologies/#{ontology_acronym}"
      subscribed = false
      user_id = nil
    else
      user = LinkedData::Client::Models::User.find(session[:user].id)
      subscribed = helpers.subscribed_to_ontology?(ontology_acronym, user)
      link = "javascript:void(0);"
      user_id = user.id
    end
    count = helpers.count_subscriptions(params[:ontology_id])
    render inline: helpers.turbo_frame_tag('subscribe_button') {
      render_to_string(OntologySubscribeButtonComponent.new(id: '', ontology_id: ontology_id, subscribed: subscribed, user_id: user_id, count: count, link: link), layout: nil)
    }
  end

  def widgets
    if request.xhr?
      render partial: 'ontologies/sections/widgets', layout: false
    else
      render partial: 'ontologies/sections/widgets', layout: 'ontology_viewer'
    end
  end

  def show_licenses

    @metadata = submission_metadata
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    @licenses = %w[hasLicense morePermissions copyrightHolder useGuidelines]
    @submission_latest = @ontology.explore.latest_submission(include: @licenses.join(","))
    render partial: 'ontologies/sections/licenses'
  end

  def ajax_ontologies

    render json: LinkedData::Client::Models::Ontology.all(include_views: true,
                                                          display: 'acronym,name', display_links: false, display_context: false)
  end

  def metrics
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    if @ontology.nil? || @ontology.errors
      ontology_not_found(params[:ontology])
    else
      @metrics = @ontology.explore.metrics(display_context: false, display_links: false)
      render partial: 'ontologies/sections/metrics'
    end
  end

  def metrics_evolution
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    key = params[:metrics_key]
    ontology_not_found(params[:ontology_id]) if @ontology.nil? || @ontology.errors

    # Retrieve submissions in descending submissionId order (should be reverse chronological order)
    @submissions = @ontology.explore.submissions({ include: "metrics" })
                            .sort { |a, b| a.submissionId.to_i <=> b.submissionId.to_i }.reverse || []

    metrics = @submissions.map { |s| s.metrics }

    data = {
      key => metrics.map { |m| m.nil? ? 0 : m[key] }
    }

    render partial: 'ontologies/sections/metadata/metrics_evolution_graph', locals: { data: data }
  end

  def ontologies_selector
    @categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    @groups = LinkedData::Client::Models::Group.all(display_links: false, display_context: false)
    @filters = ontology_filters_init(@categories, @groups)
    @select_id = params[:id]
    render 'ontologies/ontologies_selector/ontologies_selector', layout: false
  end

  def ontologies_selector_results
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: params[:showOntologyViews])
    @total_ontologies_number = @ontologies.length
    @input = params[:input] || ''
    @ontologies = @ontologies.select { |ontology| ontology.name.downcase.include?(@input.downcase) || ontology.acronym.downcase.include?(@input.downcase) }

    if params[:groups]
      @ontologies = @ontologies.select do |ontology|
        (ontology.group & params[:groups]).any?
      end
    end

    if params[:categories]
      @ontologies = @ontologies.select do |ontology|
        (ontology.hasDomain & params[:categories]).any?
      end
    end

    if params[:formats] || params[:naturalLanguage] || params[:formalityLevel] || params[:isOfType] || params[:showRetiredOntologies]
      submissions = LinkedData::Client::Models::OntologySubmission.all({ also_include_views: 'true' })
      if params[:formats]
        submissions = submissions.select { |submission| params[:formats].include?(submission.hasOntologyLanguage) }
      end
      if params[:naturalLanguage]
        submissions = submissions.select do |submission|
          (submission.naturalLanguage & params[:naturalLanguage]).any?
        end
      end
      if params[:formalityLevel]
        submissions = submissions.select { |submission| params[:formalityLevel].include?(submission.hasFormalityLevel) }
      end
      if params[:isOfType]
        submissions = submissions.select { |submission| params[:isOfType].include?(submission.isOfType) }
      end
      if params[:showRetiredOntologies]
        submissions = submissions.reject { |submission| submission.status.eql?('retired') }
      end
      @ontologies = @ontologies.select do |ontology|
        submissions.any? { |submission| submission.ontology.id == ontology.id }
      end
    end
    render 'ontologies/ontologies_selector/ontologies_selector_results'
  end

  # app/controllers/ontologies_controller.rb
  def subject_chips
    @subjects = Array(params[:subjects])
    render  partial: 'ontologies/sections/metadata/subject_chips', layout: false
  end


  private

  def get_views(ontology)
    views = ontology.explore.views || []
    views.select! { |view| view.access?(session[:user]) }
    views.sort { |a, b| a.acronym.downcase <=> b.acronym.downcase }
  end

  def ontology_relations_data(sub = @submission_latest)
    ontology_relations_array = []
    @relations_array = ["bpm:viewOf", "omv:useImports", "door:isAlignedTo", "door:ontologyRelatedTo", "omv:isBackwardCompatibleWith", "omv:isIncompatibleWith", "door:comesFromTheSameDomain", "door:similarTo",
                        "door:explanationEvolution", "voaf:generalizes", "door:hasDisparateModelling", "dct:hasPart", "voaf:usedBy", "schema:workTranslation", "schema:translationOfWork"]

    return if sub.nil?

    ont = sub.ontology
    # Get ontology relations between each other (ex: STY isAlignedTo GO)
    @relations_array.each do |relation_attr|
      relation_values = sub.send(relation_attr.to_s.split(':')[1])
      next if relation_values.nil? || relation_values.empty?

      relation_values = [relation_values] unless relation_values.kind_of?(Array)

      relation_values.each do |relation_value|
        next if relation_value.eql?(ont.acronym)

        target_id = relation_value
        target_in_portal = false
        target_ont = nil
        # if we find our portal URL in the ontology URL, then we just keep the ACRONYM to try to get the ontology.
        if relation_value.include?(helpers.portal_name.downcase)
          relation_value = relation_value.split('/').last
          target_ont = LinkedData::Client::Models::Ontology.find_by_acronym(relation_value).first
        end

        # Use acronym to get ontology from the portal
        if target_ont
          target_id = target_ont.acronym
          target_in_portal = true
        end

        ontology_relations_array.push({ source: ont.acronym, target: target_id, relation: relation_attr.to_s, targetInPortal: target_in_portal })
      end
    end

    if ont.viewOf
      target_ont = LinkedData::Client::Models::Ontology.find(ont.viewOf)
      ontology_relations_array.push({ source: ont.acronym, target: target_ont.acronym, relation: "bpm:viewOf", targetInPortal: true })
    end

    ontology_relations_array
  end

  def properties_hash_values(properties, sub: @submission_latest, custom_labels: {})
    return {} if sub.nil?

    properties.map { |x| [x.to_s, [sub.send(x.to_s), custom_labels[x.to_sym]]] }.to_h
  end

  def latest_rdf_submission(ontology)
    return @submission_latest if helpers.submission_ready?(@submission_latest)

    submissions = @ontology_submissions || ontology.explore.submissions(include: 'submissionId,submissionStatus') || []
    submissions
      .select { |s| Array(s.submissionStatus).include?('RDF') }
      .max_by { |s| s.submissionId.to_i }
  rescue StandardError
    nil
  end


  def determine_layout
    case action_name
    when 'index'
      'angular'
    else
      super
    end
  end

  def search_first_instance_id
    query, page, page_size = helpers.search_content_params
    results, _, _, _ = search_ontologies_content(query: query,
                        page: page,
                        page_size: page_size,
                        filter_by_ontologies: [@ontology.acronym],
                        filter_by_types: ["NamedIndividual"])
    results.shift # Remove the ontology entry
    return !results.blank? ? results.first[:name] : nil
  end

  def keep_only_root_categories(categories)
    categories.select do |category|
      next unless category.id
      category.id.start_with?(rest_url) || category.parentCategory.blank?
    end
  end

  def authorize_ontology_admin
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    redirect_to_home unless session[:user] && (@ontology.administeredBy.include?(session[:user].id) || session[:user].admin?)
  end
end
