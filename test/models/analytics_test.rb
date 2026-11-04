# frozen_string_literal: true

require 'test_helper'

class AnalyticsTest < ActiveSupport::TestCase
  test 'reads existing YAML analytics parameters' do
    analytics = Analytics.instantiate('params' => <<~YAML)
      ---
      query: heart
      position: '2'
      higher_ontologies:
      - MESH
      - SNOMEDCT
    YAML

    assert_equal({ 'query' => 'heart', 'position' => '2', 'higher_ontologies' => %w[MESH SNOMEDCT] },
                 analytics.params)
  end

  test 'persists the permitted parameters supplied by the analytics controller' do
    params = ActionController::Parameters.new(
      query: 'heart', position: '2', higher_ontologies: %w[MESH SNOMEDCT]
    ).permit(:query, :position, higher_ontologies: [])

    analytics = Analytics.create!(segment: 'search', action: 'result_clicked', params: params)

    assert_equal params, analytics.reload.params
    assert_predicate analytics.params, :permitted?
  end
end
