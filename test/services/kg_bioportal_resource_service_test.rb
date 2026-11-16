# frozen_string_literal: true

require 'test_helper'

class KgBioportalResourceServiceTest < ActiveSupport::TestCase
  BASE_URL = 'https://kg.example.org/resource'
  RESOURCE_URL = "#{BASE_URL}/AZDONTO/".freeze

  setup { Rails.cache.clear }
  teardown { WebMock.reset! }

  test 'returns the resource page URL when the page exists' do
    stub_request(:head, RESOURCE_URL).to_return(status: 200)

    assert_equal RESOURCE_URL, lookup
  end

  test 'returns nil when KG-BioPortal has no page for the ontology' do
    stub_request(:head, RESOURCE_URL).to_return(status: 404)

    assert_nil lookup
  end

  test 'returns nil when the lookup times out' do
    stub_request(:head, RESOURCE_URL).to_timeout

    assert_nil lookup
  end

  test 'asks KG-BioPortal once and then answers from the cache' do
    request = stub_request(:head, RESOURCE_URL).to_return(status: 200)

    2.times { lookup }

    assert_requested request, times: 1
  end

  test 'accepts a base URL with a trailing slash' do
    stub_request(:head, RESOURCE_URL).to_return(status: 200)

    assert_equal RESOURCE_URL, lookup(base_url: "#{BASE_URL}/")
  end

  test 'makes no request when no base URL is configured' do
    assert_nil lookup(base_url: nil)
    assert_not_requested :head, RESOURCE_URL
  end

  test 'is not configured in the test environment' do
    assert_nil Rails.configuration.settings.dig(:links, :kg_bioportal)
  end

  private

  def lookup(base_url: BASE_URL)
    KgBioportalResourceService.call('AZDONTO', base_url: base_url)
  end
end
