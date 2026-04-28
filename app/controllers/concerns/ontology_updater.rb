module OntologyUpdater
  extend ActiveSupport::Concern
  include SubmissionUpdater
  include TurboHelper

  def update_existent_ontology(acronym)
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    return nil if @ontology.nil?

    new_values = ontology_params
    new_values.each do |key, values|
      @ontology.send("#{key}=", values)
    rescue StandardError
      next
    end
    [@ontology, @ontology.update(values: new_values, cache_refresh_all: false)]
  end

  def ontology_from_params
    ontology = LinkedData::Client::Models::Ontology.new(values: ontology_params)
    ontology.viewOf = nil unless ontology.isView
    ontology
  end


  def ontology_params
    return {} unless params[:ontology]

    p = params.require(:ontology).permit(:name, :acronym, { administeredBy: [] }, :viewingRestriction, { acl: [] },
                                         { hasDomain: [] }, :viewOf, :isView, :subscribe_notifications, { group: [] })

    p[:administeredBy].reject!(&:blank?) if p[:administeredBy]
    p[:acl].reject!(&:blank?) if p[:acl]
    p[:hasDomain].reject!(&:blank?) if p[:hasDomain]
    p[:group].reject!(&:blank?) if p[:group]
    p[:viewOf] = '' if p.key?(:viewOf) && !p.key?(:isView)
    p.to_h
  end

  def show_new_errors(object, redirection = 'ontologies/new')
    # TODO optimize
    @ontologies = LinkedData::Client::Models::Ontology.all(include: 'acronym', include_views: true, display_links: false, display_context: false)
    @categories = LinkedData::Client::Models::Category.all
    @groups = LinkedData::Client::Models::Group.all(display_links: false, display_context: false)
    @errors = response_errors(object)
    @selected_attributes = (Array(errors_attributes) + Array(params[:submission]&.keys)).uniq
    @ontology = ontology_from_params if @ontology.nil?

    @submission = submission_from_params(params[:submission]) if params[:submission] && (@submission.nil? || @submission.errors)
    
    if redirection.is_a?(Hash) && redirection[:id]
      render_turbo_stream(replace(redirection[:id], partial: redirection[:partial]))
    else
      render redirection, status: 422
    end
  end

  def errors_attributes
    @errors = @errors[:error] if @errors && @errors[:error]
    @errors.keys.map(&:to_s) if @errors.is_a?(Hash)
  end

  def new_submission_hash(ontology, submission = nil)
    @submission = submission
    new_submission_params = submission_params(params[:submission])
    new_submission_params['released'] = Date.today.to_s

    if @submission
      old_submission_values = @submission.to_hash.delete_if {  |k, v| !copyable_submission_params?(k, v)}
      new_submission_params = ActionController::Parameters.new(old_submission_values.merge(new_submission_params))
      new_submission_params = submission_params(new_submission_params)
    end

    new_submission_params.delete 'submissionId'
    new_submission_params[:ontology] = ontology.acronym
    ActionController::Parameters.new(new_submission_params)
  end

  def update_submission_hash(acronym)
    submission_params = submission_params(params[:submission])
    submission_params[:ontology] = acronym
    submission_params
  end

  private
  def reset_agent_attributes
    helpers.agent_attributes.each do |attr|
      current_val = @submission[attr]
      new_values = Array(current_val).map do |x|
        next x if x.is_a?(LinkedData::Client::Models::Agent)
        LinkedData::Client::Models::Agent.find(x.split('/').last)
      end

      new_values = new_values.first unless current_val.is_a?(Array)

      @submission[attr] = new_values
    end
  end

  def copyable_submission_params?(key, value)
    return false if value.nil? || (value.respond_to?(:empty?) && value.empty?)

    attr_to_not_copy = [:versionIRI, :version, :deprecated, :valid, :curatedOn,
                        :pullLocation, :metadataVoc, :hasPriorVersion, :creationDate,
                        :submissionStatus]

    !attr_to_not_copy.include?(key.to_sym)
  end
end
