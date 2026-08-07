# frozen_string_literal: true

require 'test_helper'

# Tests how submission_params handles the ontology location form. That form keeps
# the inputs for all three sources (metadata only / pull URL / local file) in the
# DOM and only hides the unselected ones, so every source's field is submitted on
# every save. submission_params has to keep just the selected one.
#
# submission_metadata is stubbed to [] so these tests don't reach the API; the
# location attributes under test are permitted explicitly, not via that list.
class SubmissionUpdaterTest < ActiveSupport::TestCase
  class Harness
    include SubmissionUpdater

    def submission_metadata
      []
    end

    # submission_params is private; expose it for testing.
    def permit(raw)
      submission_params(ActionController::Parameters.new(raw))
    end
  end

  setup do
    @harness = Harness.new
    @url = 'http://example.org/ontology.owl'
  end

  test 'keeps the pull URL when Load From Url is selected' do
    result = @harness.permit(isRemote: '1', pullLocation: @url)

    assert_equal @url, result['pullLocation']
  end

  test 'blanks a stale pull URL when Upload Local File is selected' do
    result = @harness.permit(isRemote: '0', pullLocation: @url)

    # Blank rather than absent: the API only clears a string attribute when it
    # receives an empty value, so dropping the key would leave the old URL set.
    assert_equal '', result['pullLocation']
  end

  test 'blanks a stale pull URL when Metadata Only is selected' do
    result = @harness.permit(isRemote: '3', pullLocation: @url)

    assert_equal '', result['pullLocation']
  end

  test 'drops a file picked before switching to Load From Url' do
    result = @harness.permit(isRemote: '1', pullLocation: @url, filePath: 'ontology.owl')

    assert_nil result['filePath']
    assert_equal @url, result['pullLocation']
  end

  test 'keeps the file when Upload Local File is selected' do
    result = @harness.permit(isRemote: '0', filePath: 'ontology.owl')

    assert_equal 'ontology.owl', result['filePath']
  end

  test 'leaves the pull URL untouched when the location form was not submitted' do
    # Editing a single unrelated attribute posts no isRemote, and must not be
    # treated as a source change.
    result = @harness.permit(pullLocation: @url, description: 'unchanged')

    assert_equal @url, result['pullLocation']
  end
end
