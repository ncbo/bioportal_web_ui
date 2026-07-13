require 'test_helper'
require 'minitest/mock' # for Object#stub (not loaded by rails/test_help)

class ApplicationHelperTest < ActionView::TestCase
  tests ApplicationHelper

  # Save/restore the in-memory setting so mutations don't leak across tests.
  setup do
    @settings = Rails.configuration.settings
    @original_token = @settings.google_site_verification
  end

  teardown do
    @settings.google_site_verification = @original_token
  end

  test 'google_site_verification_meta_tag renders the configured token (ncbo#90)' do
    @settings.google_site_verification = 'TESTTOKEN-123'

    html = google_site_verification_meta_tag.to_s
    assert_includes html, 'name="google-site-verification"'
    assert_includes html, 'content="TESTTOKEN-123"'
  end

  test 'google_site_verification_meta_tag is omitted when no token is configured (ncbo#90)' do
    @settings.google_site_verification = nil

    assert_nil google_site_verification_meta_tag
  end

  test 'google_site_verification_meta_tag is omitted on the appliance even when configured (ncbo#90)' do
    @settings.google_site_verification = 'TESTTOKEN-123'

    Rails.stub(:env, ActiveSupport::StringInquirer.new('appliance')) do
      assert_nil google_site_verification_meta_tag
    end
  end
end
