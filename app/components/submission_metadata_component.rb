# frozen_string_literal: true

class SubmissionMetadataComponent < ViewComponent::Base
  include ApplicationHelper, MetadataHelper, SubmissionInputsHelper,OntologiesHelper

  def initialize(submission: , submission_metadata:)
    super()
    @submission = submission

    @json_metadata = submission_metadata
    @metadata_list = content_metadata_attributes(submission_metadata)
  end

  def display_attributes(metadata)
    if Array(@submission.send(metadata)).empty?
      out = 'N/A'
    else
      out = Array(@submission.send(metadata)).map do |value|
        content_tag(:div) do
          display_attribute(metadata, value)
        end
      end.join
    end
    out.html_safe
  end
end
