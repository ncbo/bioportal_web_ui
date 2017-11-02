class SubmissionsController < ApplicationController

  layout :determine_layout
  before_action :authorize_and_redirect, :only=>[:edit,:update,:create,:new]

  def new
    @ontology = LinkedData::Client::Models::Ontology.get(CGI.unescape(params[:ontology_id])) rescue nil
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first unless @ontology
    @submission = @ontology.explore.latest_submission
    @submission ||= LinkedData::Client::Models::OntologySubmission.new
  end

  def create
    # Make the contacts an array
    params[:submission][:contact] = params[:submission][:contact].values

    @submission = LinkedData::Client::Models::OntologySubmission.new(values: params[:submission])
    @ontology = LinkedData::Client::Models::Ontology.get(params[:submission][:ontology])
    # Update summaryOnly on ontology object
    @ontology.summaryOnly = @submission.isRemote.eql?("3")
    @ontology.update
    @submission_saved = @submission.save
    if !@submission_saved || @submission_saved.errors
      @errors = response_errors(@submission_saved) # see application_controller::response_errors
      if @errors[:error][:uploadFilePath] && @errors[:error][:uploadFilePath].first[:options]
        @masterFileOptions = @errors[:error][:uploadFilePath].first[:options]
        @errors = ["Please select a main ontology file from your uploaded zip"]
      else
        redirect_to "/ontologies/success/#{@ontology.acronym}"
      end
      render "new"
    else
      redirect_to "/ontologies/success/#{@ontology.acronym}"
    end
  end

  def edit
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    submissions = @ontology.explore.submissions
    @submission = submissions.select {|o| o.submissionId == params["id"].to_i}.first
  end

  def update
    # Make the contacts an array
    params[:submission][:contact] = params[:submission][:contact].values

    @ontology = LinkedData::Client::Models::Ontology.get(params[:submission][:ontology])
    submissions = @ontology.explore.submissions
    @submission = submissions.select {|o| o.submissionId == params["id"].to_i}.first

    @submission.update_from_params(params[:submission])
    # Update summaryOnly on ontology object
    @ontology.summaryOnly = @submission.isRemote.eql?("3")
    @ontology.update
    error_response = @submission.update

    if error_response
      @errors = response_errors(error_response) # see application_controller::response_errors
    else
      redirect_to "/ontologies/#{@ontology.acronym}"
    end
  end

end
