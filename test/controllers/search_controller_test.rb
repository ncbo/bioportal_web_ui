# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'ostruct'

class SearchControllerClassesTest < ActionDispatch::IntegrationTest
  test 'returns empty array for a query shorter than 2 chars' do
    get search_classes_url(q: 'f')
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test 'returns id, prefLabel, and acronym for each search result' do
    fake_result = OpenStruct.new(
      id: 'http://purl.bioontology.org/ontology/MESH/D005316',
      prefLabel: 'Fetal Distress',
      links: { 'ontology' => 'https://data.example.org/ontologies/MESH' }
    )
    unlabeled = OpenStruct.new(id: 'http://example.org/no-label', prefLabel: nil, links: {})
    fake_page = OpenStruct.new(collection: [fake_result, unlabeled])

    LinkedData::Client::Models::Class.stub(:search, fake_page) do
      get search_classes_url(q: 'fetal distress')
    end
    assert_response :success
    results = JSON.parse(response.body)
    assert_equal 1, results.length, 'results without a prefLabel should be dropped'
    assert_equal 'Fetal Distress', results.first['prefLabel']
    assert_equal 'MESH', results.first['acronym']
    assert_equal 'http://purl.bioontology.org/ontology/MESH/D005316', results.first['id']
  end

  test 'ranks exact and word-boundary label matches above other prefix matches' do
    labels = ['Contributory benefit', 'Contributory', 'Contributor Role', 'Contributor']
    fake_page = OpenStruct.new(collection: labels.map do |label|
      OpenStruct.new(id: "http://example.org/#{label.parameterize}", prefLabel: label,
                     links: { 'ontology' => 'https://data.example.org/ontologies/TST' })
    end)

    LinkedData::Client::Models::Class.stub(:search, fake_page) do
      get search_classes_url(q: 'contributor')
    end
    assert_response :success
    ranked = JSON.parse(response.body).map { |r| r['prefLabel'] }
    assert_equal ['Contributor', 'Contributor Role', 'Contributory benefit', 'Contributory'], ranked
  end
end
