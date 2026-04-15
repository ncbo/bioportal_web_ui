require 'test_helper'
require_relative '../helpers/application_test_helpers'

class ApikeyMaskingTest < ActionDispatch::IntegrationTest
  include ApplicationTestHelpers::Users

  setup do
    @user = fixtures(:users)[:bob]
    password = @user.password
    create_user(@user)
    # Authenticate to obtain the server-assigned apikey (GET users/:id does not return it)
    authed = LinkedData::Client::Models::User.authenticate(@user.username, password)
    @user = authed if authed && !authed.errors
    @user.password = password
  end

  teardown do
    delete_user(@user) rescue nil
  end

  test 'account page masks API key with reveal-component scaffolding' do
    post login_index_url, params: {
      user: { username: @user.username, password: @user.password }
    }
    assert_response :redirect, 'login POST should redirect on success'

    get user_path(@user.username)
    assert_response :success

    apikey = @user.apikey
    skip 'Test user has no apikey assigned by staging API' if apikey.blank?

    dots = '•' * 36

    # Reveal-component wraps the API key region
    assert_select "div[data-controller='reveal-component']" do
      # Dots span — visible target, no d-none
      assert_select "span.font-monospace[data-reveal-component-target='item']", text: dots

      # Real API key span — hidden target (d-none)
      assert_select "span.font-monospace.d-none[data-reveal-component-target='item']", text: apikey

      # Show button — visible, wired to toggle
      assert_select "button[data-reveal-component-target='item'][data-action='click->reveal-component#toggle']",
                    text: /Show/ do |buttons|
        assert buttons.none? { |b| b['class'].to_s.split.include?('d-none') },
               'Show button should be visible by default (no d-none)'
      end

      # Hide button — hidden, wired to toggle
      assert_select "button.d-none[data-reveal-component-target='item'][data-action='click->reveal-component#toggle']",
                    text: /Hide/

      # Clipboard copy button still present (regardless of visibility)
      assert_select 'div.clipboard[data-controller~=clipboard]'
    end
  end
end
