class MetadataExportController < ApplicationController
  include MetadataHelper

  def index
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    @submission_latest = if params[:submission_id].present?
                          @ontology.explore.submissions({ include: 'all' }, params[:submission_id])
                        else
                          @ontology.explore.latest_submission(include: 'all')
                        end
    @ontology_metadata = {}
    @ontology.to_hash.each do |k, v|
      @ontology_metadata[k] = v
    end

    content_metadata_attributes.each do |attr, label|
      value = @submission_latest.send(attr)

      if attr.to_s.eql?('contact') || agent?(attr)
        new_values = Array(value).map do  |x|
          next x if x.is_a?(String)

          x = x.to_h || x.to_hash
          x.delete(:context)
          x.delete(:links)
          x.delete(:id)
          x[:email] || x[:name]
        end
        value = value.is_a?(Array) ? new_values : new_values.first
      end
      @ontology_metadata[attr] = value
    end
  end
end
