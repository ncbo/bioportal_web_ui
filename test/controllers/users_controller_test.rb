# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class UsersControllerSearchTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @fake_user = OpenStruct.new(
      username: 'testuser',
      id: 'testuser',
      apikey: 'fake-api-key',
      admin?: false,
      errors: nil,
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      subscription: nil
    )
  end

  # Logs the fake user in by stubbing User.authenticate, so the integration
  # session has session[:user] set without hitting the real API.
  def login_fake_user
    LinkedData::Client::Models::User.stub(:authenticate, @fake_user) do
      post login_index_url, params: { user: { username: 'testuser', password: 'pass' } }
    end
  end

  # Stubs LinkedData::Client::HTTP.get so we can observe only the search-
  # action's API call. Unrelated calls made during the request lifecycle
  # (layouts, before_actions) get a benign empty response so the request
  # completes; calls that look like our search endpoint (URL contains
  # '/users' and params include :search) are recorded into `calls` and
  # served `payload`.
  def with_search_stub(payload: [])
    calls = []
    recorder = proc do |url, params = {}, *_|
      if url.to_s.include?('/users') && params.is_a?(Hash) && params[:search]
        calls << params[:search]
        payload
      else
        []
      end
    end
    LinkedData::Client::HTTP.stub(:get, recorder) do
      yield calls
    end
  end

  test 'returns 401 when not logged in' do
    get search_users_url(format: :json, q: 'alex')
    assert_response :unauthorized
  end

  test 'returns empty array for query shorter than 3 chars' do
    login_fake_user
    with_search_stub do |calls|
      get search_users_url(format: :json, q: 'al')
      assert_equal [], calls, 'search API should not be called for short query'
    end
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test 'strips whitespace before measuring query length' do
    login_fake_user
    with_search_stub do |calls|
      get search_users_url(format: :json, q: '  al  ')
      assert_equal [], calls, 'whitespace-padded short query should short-circuit'
    end
    assert_equal [], JSON.parse(response.body)
  end

  test 'returns up to 25 mapped {value, text} entries for a valid query' do
    login_fake_user
    fake_users = (1..30).map { |i| OpenStruct.new(id: "http://example.org/users/u#{i}", username: "user#{i}") }
    with_search_stub(payload: fake_users) do
      get search_users_url(format: :json, q: 'user')
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 25, body.size
    assert_equal({ 'value' => 'http://example.org/users/u1', 'text' => 'user1' }, body.first)
  end

  test 'caches results so repeat queries hit the API only once' do
    login_fake_user
    fake_users = [OpenStruct.new(id: 'http://example.org/users/alex', username: 'alex')]
    with_search_stub(payload: fake_users) do |calls|
      get search_users_url(format: :json, q: 'alex')
      get search_users_url(format: :json, q: 'alex')
      assert_equal 1, calls.size, 'second identical query should hit the cache'
    end
  end

  test 'cache key is case-insensitive' do
    login_fake_user
    fake_users = [OpenStruct.new(id: 'http://example.org/users/alex', username: 'alex')]
    with_search_stub(payload: fake_users) do |calls|
      get search_users_url(format: :json, q: 'ALEX')
      get search_users_url(format: :json, q: 'alex')
      assert_equal 1, calls.size
    end
  end
end
