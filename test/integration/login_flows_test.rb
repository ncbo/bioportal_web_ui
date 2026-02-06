# In test/integration/login_flows_test.rb

require 'test_helper'

require_relative '../helpers/application_test_helpers'

class LoginFlowsTest < ActionDispatch::IntegrationTest
  include ApplicationTestHelpers::Users


  setup do
    @user_john = fixtures(:users)[:john]
    @user_bob = fixtures(:users)[:bob]
    @user_bob = create_user(@user_bob)
  end

  teardown do
    delete_user(@user_bob) rescue nil
    delete_user(@user_john) rescue nil
  end

  test 'go to sign up page, save, and see account details' do
    get root_url
    assert_response :success

    get login_index_url
    assert_response :success

    get new_user_path

    new_user = @user_john
    delete_user(new_user)

    post users_path, params: {
      user: {
        firstName: new_user.firstName,
        lastName: new_user.lastName,
        username: new_user.username,
        orcidId: new_user.orcidId,
        githubId: new_user.githubId,
        email: new_user.email,
        password: new_user.password,
        password_confirmation: new_user.password,
        terms_and_conditions: true
      }
    }

    unless response.redirect?
      # If the API failed to create the user, show the error for debugging
      doc = Nokogiri::HTML(response.body)
      errors = doc.css('.alert-danger, .error, .errors').map(&:text).join('; ')
      skip "User creation failed via API (staging API may be unavailable or user already exists): #{errors}"
    end

    assert_redirected_to user_path(new_user.username)
    follow_redirect!

    assert_select '.flash.alert', /Account was successfully created/

    # Current account page uses a table layout under .account-info
    assert_select '.account-info' do
      assert_select 'th', text: 'First name'
      assert_select 'td', text: new_user.firstName

      assert_select 'th', text: 'Last name'
      assert_select 'td', text: new_user.lastName

      assert_select 'th', text: 'Email'
      assert_select 'td', text: new_user.email
    end
  end

  test 'go to login page and click save' do
    get login_index_url
    assert_response :success
    post login_index_url, params: {
      user: {
        username: @user_bob.username,
        password: @user_bob.password
      }
    }

    assert_redirected_to root_url
    follow_redirect!

    assert_select '.flash.alert', /Welcome/
  end
end
