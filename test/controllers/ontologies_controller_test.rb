# frozen_string_literal: true

require 'test_helper'
require "minitest/mock"
require 'ostruct'

class OntologiesControllerTest < ActionDispatch::IntegrationTest
  ONTOLOGIES = []
  if ENV['ONTOLOGIES_TO_TEST'].nil?
    ONTOLOGIES.concat(LinkedData::Client::Models::Ontology.all(include: 'acronym'))
  else
    ontologies_to_test = ENV['ONTOLOGIES_TO_TEST']&.split(',')&.map(&:strip)
    ontologies_to_test.each do | ont |
      ONTOLOGIES << LinkedData::Client::Models::Ontology.find(ont, include: 'acronym')
    end
  end

  # PAGES: schemes, collections are not yet implemented
  #PAGES = %w[summary classes properties notes mappings schemes collections widgets].freeze
  PAGES = %w[summary classes properties notes mappings widgets].freeze

  test 'should return all the ontologies' do
    get ontologies_path
    assert_response :success
  end

  ONTOLOGIES.each do |ont|
    PAGES.each do |page|
      test "should get page #{page} of #{ont.acronym} ontology" do
        path = "#{ontologies_path}/#{ont.acronym}?p=#{page}"
        get path
        if response.redirect?
          follow_redirect!
        end
        assert_response :success, "GET #{path} returned #{response.status}"
      end
    end

    test "should open the tree views of #{ont.acronym} ontology" do
      skip('functionality not yet implemented')
      paths = [
        ajax_classes_treeview_path(ontology: ont.acronym),
        "/ontologies/#{ont.acronym}/properties"
      ]
      paths.each do |path|
        begin
          get path
          assert_includes [404, 200], response.status,  "GET #{path} returned #{response.status}"
        rescue StandardError => e
          assert_equal ActiveRecord::RecordNotFound, e.class
        end
      end

    end
  end

  test 'DELETE /ontologies/:acronym/submissions requires ontology_submission_ids' do
    acronym = (ONTOLOGIES.first&.acronym || 'STY')

    delete submissions_ontology_path(acronym)
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert_equal 'ontology_submission_ids required', json['error']
  end

  test 'DELETE /ontologies/:acronym/submissions returns process_id and proxies to backend' do
    acronym = (ONTOLOGIES.first&.acronym || 'STY')
    ids = %w[3 5 7]

    called = false
    stubbed = lambda do |path, params, options|
      called = true
      assert_includes path, "/ontologies/#{acronym}/submissions"
      assert_equal "[#{ids.join(',')}]", params[:ontology_submission_ids]
      assert_equal true, options[:parse]
      OpenStruct.new(process_id: 'pid-123')
    end

    LinkedData::Client::HTTP.stub(:delete, stubbed) do
      delete submissions_ontology_path(acronym), params: { ontology_submission_ids: ids }
      assert_response :success
      json = JSON.parse(@response.body)
      assert_equal 'pid-123', json['process_id']
      assert called, 'HTTP.delete was not invoked'
    end
  end

  test 'DELETE /ontologies/:acronym/submissions surfaces backend errors' do
    acronym = (ONTOLOGIES.first&.acronym || 'STY')

    stubbed = lambda do |*_|
      raise StandardError, 'fake error'
    end

    LinkedData::Client::HTTP.stub(:delete, stubbed) do
      delete submissions_ontology_path(acronym), params: { ontology_submission_ids: %w[1] }
      assert_response :bad_gateway
      json = JSON.parse(@response.body)
      assert_match(/Delete request failed/i, json['error'])
    end
  end

  test 'GET /ontologies/:acronym/submissions/bulk_delete/:process_id proxies and returns JSON' do
    acronym    = (ONTOLOGIES.first&.acronym || 'STY')
    process_id = 'pid-xyz'

    called = false
    stubbed_get = lambda do |path, *_|
      called = true
      assert_includes path, "/ontologies/#{acronym}/submissions/bulk_delete/#{process_id}"
      # `get` returns parsed object by default; simulate that with a Hash
      { 'status' => 'processing', 'deleted_ids' => [] }
    end

    LinkedData::Client::HTTP.stub(:get, stubbed_get) do
      get bulk_delete_status_ontology_path(acronym, process_id)
      assert_response :success
      json = JSON.parse(@response.body)
      assert_equal 'processing', json['status']
      assert called, 'HTTP.get was not invoked'
    end
  end

  test 'GET /ontologies/:acronym/submissions/bulk_delete/:process_id surfaces errors' do
    acronym    = (ONTOLOGIES.first&.acronym || 'STY')
    process_id = 'pid-err'

    stubbed = lambda do |*_|
      raise StandardError, 'polling error'
    end

    LinkedData::Client::HTTP.stub(:get, stubbed) do
      get bulk_delete_status_ontology_path(acronym, process_id)
      assert_response :bad_gateway
      json = JSON.parse(@response.body)
      assert_match(/Problem retrieving bulk delete status/i, json['error'])
    end
  end

  test 'test get STY in html format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'text/html' }
    assert_response :success
    assert_equal 'text/html; charset=utf-8', response.content_type
  end

  test 'test get STY in json format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type

  end

  test 'test get STY in xml format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'application/xml' }
    assert_equal 500, response.status # STY has only Turtle
  end

  test 'test get STY in csv format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'text/csv' }
    assert_response :success
  end

  test 'test get STY in turtle format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
  end

  test 'test get STY in ntriples format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY', headers: { 'Accept' => 'application/ntriples' }
    assert_response :not_acceptable
  end

  test 'test get STY resource in html format' do
    skip('test does not account for variation of PURL settings across OntoPortal instances')
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/html' }
    assert_includes ["http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSTY%2FT071&p=classes", "http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.lirmm.fr%2Fontology%2FSTY%2FT071&p=classes"], response.location
    assert_response :redirect
    assert_equal "text/html; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in json format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal "application/ld+json; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in xml format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/xml' }
    assert_response :success
    assert_equal "application/rdf+xml; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in ntriples format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/n-triples' }
    assert_response :success
    assert_equal "application/n-triples; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in turtle format' do
    skip('functionality not yet implemented')
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
    assert_equal "text/turtle; charset=utf-8" , response.content_type
  end
end
