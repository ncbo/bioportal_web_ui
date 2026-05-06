# frozen_string_literal: true

require 'test_helper'

class MetadataExportControllerTest < ActionDispatch::IntegrationTest
  ACRONYM = 'STY'

  test 'should load metadata for the latest submission when no submission_id is given' do
    get metadata_export_index_path(ontology: ACRONYM)
    assert_response :success
  end

  test 'should load metadata for a specific submission when submission_id is given' do
    ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ACRONYM).first
    submission_id = ontology.explore.submissions(include: 'submissionId').first.submissionId

    get metadata_export_index_path(ontology: ACRONYM, submission_id: submission_id)
    assert_response :success
  end

end
