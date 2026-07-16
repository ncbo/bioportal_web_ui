# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'ostruct'

class MappingsControllerNewTest < ActionDispatch::IntegrationTest
  setup do
    @fake_user = OpenStruct.new(
      username: 'testuser',
      id: 'testuser',
      apikey: 'fake-api-key',
      admin?: false,
      errors: nil,
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      subscription: nil
    )

    @fake_concept = OpenStruct.new(id: 'http://example.org/ontology#C1', prefLabel: 'Test Class')
    fake_explore = Object.new
    concept = @fake_concept
    fake_explore.define_singleton_method(:single_class) { |*_args| concept }
    @fake_ontology = OpenStruct.new(
      acronym: 'TST',
      id: 'https://data.example.org/ontologies/TST',
      explore: fake_explore
    )
  end

  # Logs the fake user in by stubbing User.authenticate, so the integration
  # session has session[:user] set without hitting the real API.
  def login_fake_user
    LinkedData::Client::Models::User.stub(:authenticate, @fake_user) do
      post login_index_url, params: { user: { username: 'testuser', password: 'pass' } }
    end
  end

  test 'redirects to home when not logged in' do
    get new_mapping_url(ontology_from: @fake_ontology.id, conceptid_from: @fake_concept.id)
    assert_response :redirect
  end

  # Regression test for https://github.com/ncbo/bioportal_web_ui/issues/476:
  # the Create New Mapping button passes only the source ontology and class,
  # and new must not crash on the absent ontology_to/conceptid_to params.
  test 'renders the modal form when only source params are given' do
    login_fake_user
    LinkedData::Client::Models::Ontology.stub(:find, @fake_ontology) do
      LinkedData::Client::Models::Ontology.stub(:all, []) do
        get new_mapping_url(ontology_from: @fake_ontology.id, conceptid_from: @fake_concept.id)
      end
    end
    assert_response :success
    assert_includes response.body, 'turbo-frame id="modal"'
    assert_includes response.body, 'Test Class'
    assert_includes response.body, 'map_to_bioportal_full_id'
  end

  test 'returns 404 when the source class is not provided' do
    login_fake_user
    get new_mapping_url
    assert_response :not_found
  end
end
