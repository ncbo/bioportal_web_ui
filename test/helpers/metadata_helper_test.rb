require 'test_helper'

class MetadataHelperTest < ActionView::TestCase
  tests MetadataHelper

  test 'content_metadata_attributes hides uriLookupEndpoint' do
    metadata = [
      { 'attribute' => 'uriLookupEndpoint', 'label' => 'URI Lookup Endpoint' },
      { 'attribute' => 'naturalLanguage',   'label' => 'Natural Language' },
      { 'attribute' => 'description',       'label' => 'Description' }
    ]

    result = content_metadata_attributes(metadata).to_h

    refute result.key?('uriLookupEndpoint'),
           'uriLookupEndpoint should be filtered out (closes ncbo#450)'
    refute result.key?('description'),
           'description should remain filtered (existing behavior)'
    assert result.key?('naturalLanguage'),
           'non-blacklisted attributes should pass through'
  end
end
