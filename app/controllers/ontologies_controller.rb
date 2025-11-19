class OntologiesController < ApplicationController
  include MappingsHelper
  include MappingStatistics
  include SchemesHelper, CollectionsHelper
  include MultiLanguagesHelper
  include OntologyUpdater

  require "multi_json"
  require 'cgi'

  helper :concepts
  layout :determine_layout

  before_action :authorize_and_redirect, :only=>[:edit,:update,:create,:new]

  KNOWN_PAGES = Set.new(["terms", "classes", "mappings", "notes", "widgets", "summary", "properties", "schemes", "collections"])

  ONTOLOGY_REST_URL = "#{LinkedData::Client.settings.rest_url}/ontologies/:acronym"
  SUBMISSIONS_REST_URL = "#{ONTOLOGY_REST_URL}/submissions"
  USER_ONTOLOGY_ADMIN_URL = "#{ONTOLOGY_REST_URL}/admin"
  BULK_DELETE_PROGRESS_URL = "#{SUBMISSIONS_REST_URL}/bulk_delete/:process_id"

  include ActionView::Helpers::NumberHelper
  include OntologiesHelper
  def index
    @app_name = "FacetedBrowsing"
    @app_dir = "/browse"
    @base_path = @app_dir
    ontologies = LinkedData::Client::Models::Ontology.all(include: LinkedData::Client::Models::Ontology.include_params + ",viewOf", include_views: true, display_context: false)
    ontologies_hash = Hash[ontologies.map {|o| [o.id, o] }]
    @admin = session[:user] ? session[:user].admin? : false
    @development = Rails.env.development?

    submissions = LinkedData::Client::Models::OntologySubmission.all(include_views: true, display_links: false, display_context: false, include: "submissionStatus,hasOntologyLanguage,pullLocation,description,creationDate,status")
    submissions_map = submissions.each_with_object({}) do |sub, h|
      ontology_id = sub.id.sub(%r{/submissions/[^/]+$}, '')
      if (ontology = ontologies_hash[ontology_id])
        h[ontology.acronym] = sub
      end
    end

    @categories = LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    @categories_hash = Hash[@categories.map {|c| [c.id, c] }]

    @groups = LinkedData::Client::Models::Group.all(display_links: false, display_context: false)
    @groups_hash = Hash[@groups.map {|g| [g.id, g] }]

    analytics = LinkedData::Client::Analytics.last_month
    @analytics = Hash[analytics.onts.map {|o| [o[:ont].to_s, o[:views]]}]

    metrics_hash = get_metrics_hash

    @formats = Set.new

    @ontologies = []
    ontologies.each do |ont|
      o = {}

      if metrics_hash[ont.id]
        o[:class_count] = metrics_hash[ont.id].classes
        o[:individual_count] = metrics_hash[ont.id].individuals
      else
        o[:class_count] = 0
        o[:individual_count] = 0
      end
      o[:class_count_formatted] = number_with_delimiter(o[:class_count], :delimiter => ",")
      o[:individual_count_formatted] = number_with_delimiter(o[:individual_count], :delimiter => ",")

      o[:id]               = ont.id
      o[:type]             = ont.viewOf.nil? ? "ontology" : "ontology_view"
      o[:show]             = ont.viewOf.nil? ? true : false # show ontologies only by default
      o[:groups]           = ont.group || []
      o[:categories]       = ont.hasDomain || []
      o[:note_count]       = ont.notes.length
      o[:project_count]    = ont.projects.length
      o[:private]          = ont.private?
      o[:popularity]       = @analytics[ont.acronym] || 0
      o[:submissionStatus] = []
      o[:administeredBy]   = ont.administeredBy
      o[:name]             = ont.name
      o[:acronym]          = ont.acronym
      o[:projects]         = ont.projects
      o[:notes]            = ont.notes

      if o[:type].eql?("ontology_view")
        unless ontologies_hash[ont.viewOf].blank?
          o[:viewOfOnt] = {
            name: ontologies_hash[ont.viewOf].name,
            acronym: ontologies_hash[ont.viewOf].acronym
          }
        end
      end

      o[:artifacts] = []
      o[:artifacts] << "notes" if ont.notes.length > 0
      o[:artifacts] << "projects" if ont.projects.length > 0
      o[:artifacts] << "summary_only" if ont.summaryOnly

      sub = submissions_map[ont.acronym]
      if sub
        o[:submissionStatus]          = sub.submissionStatus
        o[:submission]                = true
        o[:pullLocation]              = sub.pullLocation
        o[:description]               = sub.description
        o[:creationDate]              = sub.creationDate
        o[:submissionStatusFormatted] = submission_status2string(sub)

        o[:format] = sub.hasOntologyLanguage
        @formats << sub.hasOntologyLanguage
      else
        # Used to sort ontologies without subnissions to the end when sorting on upload date
        o[:creationDate] = DateTime.parse("19900601")
      end

      @ontologies << o
    end

    @ontologies.sort! {|a,b| b[:popularity] <=> a[:popularity]}

    render 'browse'
  end

  def classes
    @submission = get_ontology_submission_ready(@ontology)
    get_class(params, @submission)

    if @submission.hasOntologyLanguage == 'SKOS'
      @schemes = get_schemes(@ontology)
      @collections = get_collections(@ontology, add_colors: true)
    end

    if ["application/ld+json", "application/json"].include?(request.accept)
      render plain: @concept.to_jsonld, content_type: request.accept and return
    end

    @current_purl = @concept.purl if Rails.configuration.settings.purl[:enabled]

    unless @concept.id == "bp_fake_root"
      @notes = @concept.explore.notes
    end
    
    update_tab(@ontology, @concept.id)

    if request.xhr?
      render "ontologies/sections/visualize", layout: false
    else
      render "ontologies/sections/visualize", layout: "ontology_viewer"
    end
  end

  def properties
    if request.xhr?
      return render 'properties', :layout => false
    else
      return render 'properties', :layout => "ontology_viewer"
    end
  end

  def create
    @is_update_ontology = false
    @ontology = ontology_from_params.save(cache_refresh_all: false)

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
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id], {include: 'all', display_links: false, display_context: false}).first
    return unless authorize_ontology_admin(@ontology)

    submission = @ontology.explore.latest_submission(include: 'submissionId')
    if submission
      redirect_to edit_ontology_submission_path(@ontology.acronym, submission.submissionId)
    else
      redirect_to new_ontology_submission_path(@ontology.acronym)
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
    @user_select_list = LinkedData::Client::Models::User.all(include: 'username').map { |u| [u.username, u.id] }
    @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
  end

  # GET /ontologies/1
  # GET /ontologies/1.xml
  def show
    # Hack to make ontologyid and conceptid work in addition to id and ontology params
    params[:id] = params[:id].nil? ? params[:ontologyid] : params[:id]
    params[:ontology] = params[:ontology].nil? ? params[:id] : params[:ontology]

    # PURL-specific redirect to handle /ontologies/{ACR}/{CLASS_ID} paths
    if params[:purl_conceptid]
      params[:purl_conceptid] = "root" if params[:purl_conceptid].eql?("classes")
      if params[:conceptid]
        params.delete(:purl_conceptid)
      else
        params[:conceptid] = params.delete(:purl_conceptid)
      end
      redirect_to "/ontologies/#{params[:acronym]}?p=classes#{params_string_for_redirect(params, prefix: "&")}", :status => :moved_permanently
      return
    end

    # Note: find_by_acronym includes ontology views
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology], include: 'all').first
    not_found if @ontology.nil? || (@ontology.errors && [401, 403, 404].include?(@ontology.status))

    # Handle the case where an ontology is converted to summary only.
    # See: https://github.com/ncbo/bioportal_web_ui/issues/133.
    if @ontology.summaryOnly && params[:p].present?
      pages = KNOWN_PAGES - ["summary", "notes"]
      if pages.include?(params[:p])
        redirect_to(ontology_path(params[:ontology]), status: :temporary_redirect) and return
      end
    end

    # Retrieve submissions in descending submissionId order (should be reverse chronological order)
    @submissions = @ontology.explore.submissions.sort {|a,b| b.submissionId.to_i <=> a.submissionId.to_i } || []
    Log.add :error, "No submissions for ontology: #{@ontology.id}" if @submissions.empty?

    # Get the latest submission (not necessarily the latest 'ready' submission)
    @submission_latest = @ontology.explore.latest_submission rescue @ontology.explore.latest_submission(include: "")

    # show summary only for ontologies without any submissions in ready state
    unless helpers.submission_ready?(@submission_latest)
      submissions = @ontology.explore.submissions(include: 'submissionId,submissionStatus')
      if submissions.any?{|x| helpers.submission_ready?(x)}
        @old_submission_ready = true
      elsif !params[:p].blank?
        params[:p] = "summary"
      end
    end

    # Is the ontology downloadable?
    restrict_downloads = $NOT_DOWNLOADABLE
    @ont_restricted = restrict_downloads.include? @ontology.acronym

    # Fix parameters to only use known pages
    params[:p] = nil unless KNOWN_PAGES.include?(params[:p])

    # This action is now a router using the 'p' parameter as the page to show
    case params[:p]
      when "terms"
        params[:p] = 'classes'
        redirect_to "/ontologies/#{params[:ontology]}#{params_string_for_redirect(params)}", :status => :moved_permanently
        return
      when "classes"
        self.classes #rescue self.summary
        return
      when "mappings"
        self.mappings #rescue self.summary
        return
      when "notes"
        self.notes #rescue self.summary
        return
      when "widgets"
        self.widgets #rescue self.summary
        return
      when "properties"
        self.properties #rescue self.summary
        return
      when "summary"
        self.summary
        return
      when 'schemes'
        self.schemes
      when 'collections'
        self.collections
      else
        self.summary
        return
    end
  end

  def destroy
    acronym = params[:acronym]
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym, include: 'all').first
    return unless authorize_ontology_admin(@ontology)

    error_response = @ontology.delete

    if response_error?(error_response)
      respond_to do |format|
        format.json { render json: { error: "Failed to delete ontology #{acronym}: #{response_errors(error_response)}" }, status: :unprocessable_entity }
        format.html do
          flash[:error] = "Failed to delete ontology #{acronym}: #{response_errors(error_response)}"
          redirect_to admin_ontology_path(acronym)
        end
      end
    else
      respond_to do |format|
        format.json { render json: { redirect_url: ontologies_path }, status: :ok }
        format.html { redirect_to ontologies_path, notice: "Ontology #{acronym} successfully deleted." }
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { render json: { error: "Failed to delete ontology #{acronym}: #{e.message}" }, status: :bad_gateway }
      format.html do
        flash[:error] = "Failed to delete ontology #{acronym}: #{e.message}"
        redirect_to admin_ontology_path(acronym)
      end
    end
  end

  def mappings
    @mapping_counts = mapping_counts(@ontology.acronym)

    if request.xhr?
      render partial: 'mappings', layout: false
    else
      render partial: 'mappings', layout: 'ontology_viewer'
    end
  end

  def admin
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:acronym], include: 'all').first
    not_found if @ontology.nil? || (@ontology.errors && [401, 403, 404].include?(@ontology.status))
    return unless authorize_ontology_admin(@ontology)

    restrict_downloads = $NOT_DOWNLOADABLE
    @ont_restricted = restrict_downloads.include? @ontology.acronym

    # Retrieve submissions in descending submissionId order (should be reverse chronological order)
    @submissions = uncached_sorted_submissions_for(@ontology.acronym)
    Log.add :error, "No submissions found for ontology: #{@ontology.id}" if @submissions.empty?

    # Get the latest submission (not necessarily the latest 'ready' submission)
    @submission_latest = @ontology.explore.latest_submission rescue @ontology.explore.latest_submission(include: "")

    render template: 'ontologies/admin', layout: 'ontology_viewer'
  end

  def submission_rows
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:acronym]).first
    @submissions = uncached_sorted_submissions_for(@ontology.acronym)
    render partial: "ontologies/submission_rows", formats: [:html]
  end

  def submission_log
    acronym = params[:acronym]
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym, {include: 'all'}).first
    not_found if @ontology.nil? || (@ontology.errors && [401, 403, 404].include?(@ontology.status))
    return unless authorize_ontology_admin(@ontology)

    uri = URI.parse("#{USER_ONTOLOGY_ADMIN_URL.sub(':acronym', acronym)}/log")
    payload = LinkedData::Client::HTTP.get(uri, {severity: 'ERROR'}, raw: true)

    text = fetch_log_text(payload).to_s
    text = "The processing log for the latest submission of ontology #{acronym} contains no errors" if text.strip.empty?
    render plain: text, content_type: 'text/plain'
  rescue => e
    render plain: "Failed to load log: #{e.message}", status: :bad_gateway
  end

  def submissions
    acronym = params[:acronym]
    ids = Array(params[:ontology_submission_ids]).map(&:to_s).reject(&:blank?).uniq
    return render json: { error: "ontology_submission_ids required" }, status: :unprocessable_entity if ids.empty?

    unless ids.all? { |id| id =~ /\A\d+\z/ }
      return render json: { error: "ontology_submission_ids must be integers" }, status: :unprocessable_entity
    end

    path = SUBMISSIONS_REST_URL.sub(':acronym', acronym)

    begin
      res = LinkedData::Client::HTTP.delete(path, { ontology_submission_ids: "[#{ids.join(',')}]" }, parse: true)
    rescue StandardError => e
      return render json: { error: "Delete request failed", detail: e.message }, status: :bad_gateway
    end
    process_id = res&.process_id

    if process_id.blank?
      # If the service returned a structured error, surface it
      err_msg = (res.respond_to?(:error) && res.error) ? res.error : "process_id not returned"
      return render json: { error: err_msg }, status: :bad_gateway
    end
    render json: { process_id: process_id }
  end

  def bulk_delete_status
    acronym = params['acronym']
    process_id = params['process_id']

    path = BULK_DELETE_PROGRESS_URL.sub(':acronym', acronym).sub(':process_id', process_id)
    json = LinkedData::Client::HTTP.get(path, {}, raw: true)
    payload = JSON.parse(json)
    render json: payload
  rescue StandardError => e
    render json: { error: "Problem retrieving bulk delete status - #{e.message}" }, status: :bad_gateway
  end

  def notes
    @notes = @ontology.explore.notes
    @notes_deletable = false
    # TODO_REV: Handle notes deletion
    # @notes.each {|n| @notes_deletable = true if n.deletable?(session[:user])} if @notes.kind_of?(Array)
    @note_link = "/ontologies/#{@ontology.acronym}/notes/"
    if request.xhr?
      render :partial => 'notes', :layout => false
    else
      render :partial => 'notes', :layout => "ontology_viewer"
    end
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

  def submit_success
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id], include: 'all').first
    render 'submit_success'
  end

  def summary
    # Check to see if user is requesting RDF+XML. If so, return the file from the REST service.
    if request.accept.to_s.eql?("application/ld+json") || request.accept.to_s.eql?("application/json")
      headers['Content-Type'] = request.accept.to_s
      render plain: @ontology.to_jsonld
      return
    end
    
    @metrics = @ontology.explore.metrics rescue []
    @projects = @ontology.explore.projects.sort { |a,b| a.name.downcase <=> b.name.downcase } || []
    @analytics = LinkedData::Client::HTTP.get(@ontology.links["analytics"])
    @views = get_views(@ontology)
    @view_decorators = @views.map{ |view| ViewDecorator.new(view, view_context) }
    
    if request.xhr?
      render partial: "metadata", layout: false
    else
      render partial: "metadata", layout: "ontology_viewer"
    end
  end

  def update
    if params['commit'] == 'Cancel'
      acronym = params['id']
      redirect_to "/ontologies/#{acronym}"
      return
    end
    # Note: find_by_acronym includes ontology views
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    @ontology.update_from_params(ontology_params)
    error_response = @ontology.update(cache_refresh_all: false)
    if response_error?(error_response)
      @categories = LinkedData::Client::Models::Category.all
      @user_select_list = LinkedData::Client::Models::User.all.map {|u| [u.username, u.id]}
      @user_select_list.sort! {|a,b| a[1].downcase <=> b[1].downcase}
      @errors = response_errors(error_response)
      @errors = {acronym: "Acronym already exists, please use another"} if error_response.status == 409
    else
      # TODO_REV: Enable subscriptions
      # if params["ontology"]["subscribe_notifications"].eql?("1")
      #  DataAccess.createUserSubscriptions(@ontology.administeredBy, @ontology.ontologyId, NOTIFICATION_TYPES[:all])
      # end
      redirect_to "/ontologies/#{@ontology.acronym}"
    end
  end

  def widgets
    if request.xhr?
      render :partial => 'widgets', :layout => false
    else
      render :partial => 'widgets', :layout => "ontology_viewer"
    end
  end

  private

  def uncached_sorted_submissions_for(acronym, include: 'all')
    path = SUBMISSIONS_REST_URL.sub(':acronym', acronym)
    res  = LinkedData::Client::HTTP.get(path, { include: include, invalidate_cache: true, _bust: Time.now.to_i })
    Array(res).sort { |a, b| b.submissionId.to_i <=> a.submissionId.to_i }
  rescue StandardError => _e
    []
  end

  def determine_layout
    case action_name
    when 'index'
      'angular'
    else
      super
    end
  end

  def get_views(ontology)
    views = ontology.explore.views || []
    views.select!{ |view| view.access?(session[:user]) }
    views.sort{ |a,b| a.acronym.downcase <=> b.acronym.downcase }
  end

  # Accepts an already-fetched payload (String or parsed JSON) and normalizes it to text
  def fetch_log_text(payload)
    # If the payload is a String, try to parse JSON; otherwise treat it as plain text
    if payload.is_a?(String)
      begin
        json = JSON.parse(payload)
      rescue StandardError
        return payload # not JSON → assume it’s already text
      end
    else
      json = payload
    end

    # Hash shapes
    if json.is_a?(Hash)
      return json['lines'].join("\n") if json['lines'].is_a?(Array)
      return json['text'].to_s if json.key?('text')
    end

    # Array shapes: strings or objects
    if json.is_a?(Array)
      return json.map { |row|
        if row.is_a?(Hash)
          ts  = row['ts'] || row['timestamp'] || ''
          lvl = row['level'] || row['lvl'] || ''
          msg = row['msg'] || row['message'] || row['log'] || row.to_s
          header = [ts, lvl].reject { |v| v.respond_to?(:empty?) ? v.empty? : !v }.join(' ')
          header.empty? ? msg.to_s : (msg.to_s.empty? ? header : "#{header} #{msg}")
        else
          row.to_s
        end
      }.join("\n")
    end

    # Fallback for anything else
    json.to_s
  end

end
