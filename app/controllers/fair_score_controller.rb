class FairScoreController < ApplicationController

  helper FairScoreHelper
  include FairScoreHelper

  def details_html
    get_fair
    render partial: 'details'
  end

  def details_json
    get_fair
    render json: @fair_scores_data
  end

  def foops_json
    ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontologies])&.first
    return render json: { error: 'not found' }, status: :not_found if ontology.nil?
    render json: get_foops_score(ontology)
  end

  private

  def get_fair
    ontology_not_found('') if params[:ontologies].nil? || params[:ontologies].empty?
    @ontologies = params[:ontologies]

    begin
      if @ontologies.include?(',')
        @fair_scores_data = create_fair_scores_data(get_fair_combined_score(@ontologies), @ontologies.split(',').length)

      elsif @ontologies.eql?('all')
        tmp = get_fairness_json(@ontologies)
        @fair_scores_data = create_fair_scores_data(tmp['combinedScores'], tmp['ontologies'].keys.length)

      elsif params[:foops] == 'true'
        # FOOPS! path — raw checks in FairScore component format
        @is_foops = true
        ontology = LinkedData::Client::Models::Ontology.find_by_acronym(@ontologies).first
        @rest_uri = "#{REST_URI}/ontologies/#{@ontologies}/latest_submission?display=all"
        @fair_scores_data = create_foops_raw_scores_data(get_foops_score(ontology))

      else
        # Standard O'FAIRe path
        @rest_uri = "#{REST_URI}/ontologies/#{@ontologies}/latest_submission?display=all"
        @fair_scores_data = create_fair_scores_data(get_fair_score(@ontologies).values.first, 1)
      end
    rescue NameError => e
      Rails.logger.warn "FairScoreController#get_fair NameError: #{e.message}"
    end
  end
end