require 'test_helper'

# Exercises the full request/response stack: a real page rendered through the
# `ontology` layout (which renders layouts/_header, talking to the configured
# staging API) must wire in the google-site-verification meta tag via the
# helper. Complements the helper unit test with end-to-end coverage. (ncbo#90)
class GoogleSiteVerificationTest < ActionDispatch::IntegrationTest
  setup do
    @settings = Rails.configuration.settings
    @original_token = @settings.google_site_verification
  end

  teardown do
    @settings.google_site_verification = @original_token
  end

  test 'verification meta tag is rendered into a real page when configured' do
    @settings.google_site_verification = 'INTEG-TOKEN-XYZ'

    get login_index_url
    assert_response :success
    assert_select 'meta[name=?][content=?]', 'google-site-verification', 'INTEG-TOKEN-XYZ'
  end

  test 'verification meta tag is absent from a real page when not configured' do
    @settings.google_site_verification = nil

    get login_index_url
    assert_response :success
    assert_select 'meta[name="google-site-verification"]', false,
                  'no verification meta tag should be emitted when unconfigured'
  end
end
