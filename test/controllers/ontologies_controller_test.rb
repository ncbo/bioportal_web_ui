# frozen_string_literal: true

require 'test_helper'

class OntologiesControllerTest < ActionDispatch::IntegrationTest
  ONTOLOGIES = LinkedData::Client::Models::Ontology.all(include: 'acronym')
  PAGES = %w[summary classes properties notes mappings schemes collections widgets].freeze

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

  test 'test get STY in html format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/html' }
    assert_response :success
    assert_equal 'text/html; charset=utf-8', response.content_type
  end

  test 'test get STY in json format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type

  end

  test 'test get STY in xml format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/xml' }
    assert_equal 500, response.status # STY has only Turtle
  end

  test 'test get STY in csv format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/csv' }
    assert_response :success
  end

  test 'test get STY in turtle format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
  end

  test 'test get STY in ntriples format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/ntriples' }
    assert_response :not_acceptable
  end

  
  test 'test get STY resource in html format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/html' }
    assert_includes ["http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSTY%2FT071&p=classes", "http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.lirmm.fr%2Fontology%2FSTY%2FT071&p=classes"], response.location
    assert_response :redirect
    assert_equal "text/html; charset=utf-8" , response.content_type
  end
  
  test 'test get STY resource in json format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal "application/ld+json; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in xml format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/xml' }
    assert_response :success
    assert_equal "application/rdf+xml; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in ntriples format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/n-triples' }
    assert_response :success
    assert_equal "application/n-triples; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in turtle format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
    assert_equal "text/turtle; charset=utf-8" , response.content_type
  end
end
