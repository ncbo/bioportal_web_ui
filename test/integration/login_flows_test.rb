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
    delete_user(@user_bob)
    delete_user(@user_john)
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

    assert_redirected_to ontologies_url
    follow_redirect!

    assert_select '.notification', text: 'Account was successfully created'

    get "/accounts/#{new_user.username}"
    assert_response :success

    assert_select '.account-page-title', text: 'My account'

    assert_select '.title', text: 'First name:'
    assert_select '.info', text: new_user.firstName

    assert_select '.title', text: 'Last name:'
    assert_select '.info', text: new_user.lastName

    assert_select '.title', text: 'Email:'
    assert_select '.info', text: new_user.email

    assert_select '.title', text: 'Username:'
    assert_select '.info', text: new_user.username

    assert_select '.title', text: 'ORCID ID:'
    assert_select '.info', text: new_user.orcidId

    assert_select '.title', text: 'GitHub ID:'
    assert_select '.info', text: new_user.githubId
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

    assert_select '.notification', text: "Welcome #{@user_bob.username}!"
  end
end
