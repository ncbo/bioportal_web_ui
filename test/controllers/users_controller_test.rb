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

  test 'returns 401 when not logged in' do
    get search_users_url(format: :json, q: 'alex')
    assert_response :unauthorized
  end

  test 'returns empty array for query shorter than 3 chars' do
    login_fake_user
    # Stub HTTP.get to a sentinel that would fail the assertion if reached;
    # short queries must short-circuit before any API call.
    LinkedData::Client::HTTP.stub(:get, ->(*) { flunk 'API should not be called for short query' }) do
      get search_users_url(format: :json, q: 'al')
    end
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test 'returns up to 25 mapped {value, text} entries for a valid query' do
    login_fake_user
    fake_users = (1..30).map { |i| OpenStruct.new(id: "http://example.org/users/u#{i}", username: "user#{i}") }
    LinkedData::Client::HTTP.stub(:get, fake_users) do
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
    call_count = 0
    counting_get = lambda do |*_args|
      call_count += 1
      fake_users
    end
    LinkedData::Client::HTTP.stub(:get, counting_get) do
      get search_users_url(format: :json, q: 'alex')
      get search_users_url(format: :json, q: 'alex')
    end
    assert_equal 1, call_count, 'second identical query should hit the cache'
  end

  test 'cache key is case-insensitive' do
    login_fake_user
    fake_users = [OpenStruct.new(id: 'http://example.org/users/alex', username: 'alex')]
    call_count = 0
    counting_get = lambda do |*_args|
      call_count += 1
      fake_users
    end
    LinkedData::Client::HTTP.stub(:get, counting_get) do
      get search_users_url(format: :json, q: 'ALEX')
      get search_users_url(format: :json, q: 'alex')
    end
    assert_equal 1, call_count
  end
end
