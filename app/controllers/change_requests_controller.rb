# frozen_string_literal: true

class ChangeRequestsController < ApplicationController
  before_action :require_login
  before_action :set_common_instance_variables, except: [:create]

  def node_obsoletion
    respond_to :turbo_stream
  end

  def node_rename
    respond_to :turbo_stream
  end

  def edit_definition
    @definition = params[:concept_definition]
    respond_to :turbo_stream
  end

  def create_synonym
    respond_to :js
  end

  def remove_synonym
    @concept_synonyms = params[:concept_synonyms].sort! { |a, b| a.downcase <=> b.downcase }
    respond_to :js
  end

  def create
    params[:curie] = generate_curie(params[:ont_acronym], params[:concept_id])
    params[:content] = KGCL::IssueContentGenerator.call(params)

    begin
      result = IssueCreatorService.call(params)
    rescue  StandardError => e
      result =  { success: false, error: e.message }
    end
    if result[:success]
      flash.now.notice = helpers.change_request_success_message(result[:issue])
    else
      flash.now.alert = "Change request failed: #{result[:error]}"
    end

    # TODO: remove format.js from this block, and the create.js.erb file after the create_synonym and
    #   remove_synonym actions are converted from Rails UJS to Turbo Streams.
    respond_to do |format|
      format.js
      format.turbo_stream
    end
  end

  private

  def generate_curie(ont_acronym, concept_id)
    ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ont_acronym).first
    query_string = { display: 'notation,prefixIRI', display_links: false, display_context: false }
    concept = ontology.explore.single_class(query_string, concept_id)

    if concept.notation
      concept.notation
    elsif concept.prefixIRI
      concept.prefixIRI
    else
      concept_id
    end
  end

  def require_login
    return unless session[:user].blank?

    # TODO: remove format.js handling after the create_synonym and remove_synonym actions are converted
    #   from Rails UJS to Turbo Streams.
    respond_to do |format|
      format.any(:html, :turbo_stream) { redirect_to login_index_path }
      format.js { render js: "window.location.href='#{login_index_path}'", status: :found }
    end
  end

  def set_common_instance_variables
    @concept_label = params[:concept_label]
    @concept_id = params[:concept_id]
    @ont_acronym = params[:ont_acronym]
    @user = LinkedData::Client::Models::User.get(
      session[:user].username, include: 'username,githubId,orcidId', display_links: 'false', display_context: 'false'
    )
  end
end
