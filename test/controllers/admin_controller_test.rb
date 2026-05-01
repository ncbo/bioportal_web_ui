# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class AdminControllerTest < ActionDispatch::IntegrationTest
  # Note: GET /admin/users currently has no admin-only enforcement (no
  # before_action on AdminController, and the `users` action doesn't check
  # session[:user]&.admin?). If that's tightened later, seed an admin
  # session in setup — e.g. by stubbing ApplicationController#current_user_admin?
  # to return true, or by signing in as an admin fixture.

  # Regression: /users now always returns a paged response. _users must walk
  # nextPage and concatenate `collection` so the frontend keeps receiving a
  # flat Array. Without this, the Admin Users tab JS at bp_admin.js:904
  # throws "Uncaught TypeError: users.forEach is not a function".
  test '_users flattens a multi-page paged /users response' do
    page1 = {
      'page' => 1, 'pageCount' => 2, 'totalCount' => 3, 'nextPage' => 2,
      'collection' => [sample_user('a'), sample_user('b')]
    }
    page2 = {
      'page' => 2, 'pageCount' => 2, 'totalCount' => 3, 'nextPage' => nil,
      'collection' => [sample_user('c')]
    }

    calls = []
    fake_get = lambda do |_url, params, _opts|
      calls << params
      (params[:page] == 2 ? page2 : page1).to_json
    end

    LinkedData::Client::HTTP.stub :get, fake_get do
      get '/admin/users'
      assert_response :success

      body = JSON.parse(@response.body)
      assert_kind_of Array, body['users'], 'frontend contract: data["users"] must be an Array'
      assert_equal %w[a b c], body['users'].map { |u| u['username'] }
      assert_empty body['errors']
    end

    assert_equal 2, calls.length, 'should walk both pages'
    assert_equal 5000, calls.first[:pagesize], 'should request large pagesize to minimize round trips'
    assert_equal 2, calls.last[:page], 'second call should request page=2'
  end

  # Back-compat: tolerates the legacy flat-Array response shape during the
  # rollout window when the deployed API may not yet enforce pagination.
  test '_users tolerates a flat-array response from a non-paginated API' do
    legacy = [sample_user('a'), sample_user('b')]

    LinkedData::Client::HTTP.stub :get, ->(*) { legacy.to_json } do
      get '/admin/users'
      assert_response :success

      body = JSON.parse(@response.body)
      assert_kind_of Array, body['users']
      assert_equal %w[a b], body['users'].map { |u| u['username'] }
    end
  end

  private

  def sample_user(name)
    {
      '@id' => "http://test/users/#{name}",
      'username' => name,
      'email' => "#{name}@test",
      'role' => ['LIBRARIAN'],
      'firstName' => name.upcase,
      'lastName' => "#{name.upcase}-last",
      'created' => '2026-01-01'
    }
  end
end
