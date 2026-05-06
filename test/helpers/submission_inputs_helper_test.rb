# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

# Tests for the user_select_input helper. Stubs the downstream `select_input`
# helper to capture the args without rendering anything, and stubs User.get to
# avoid hitting the API. The test verifies the helper's contract: which IDs
# get hydrated, which get filtered, and what gets passed downstream.
class SubmissionInputsHelperTest < ActionView::TestCase
  include SubmissionInputsHelper

  attr_accessor :captured_args

  # Override select_input from InputsHelper for these tests so we can assert
  # what user_select_input passes downstream without invoking the full
  # ViewComponent rendering stack.
  def select_input(**args)
    @captured_args = args
    'STUB'
  end

  setup do
    @captured_args = nil
  end

  test 'rejects blank or nil IDs and skips API calls for them' do
    fake = OpenStruct.new(username: 'alex', id: 'http://example.org/users/alex')
    call_count = 0
    counting_get = lambda do |*_args|
      call_count += 1
      fake
    end
    LinkedData::Client::Models::User.stub(:get, counting_get) do
      user_select_input(name: 'x', selected: ['', nil, 'http://example.org/users/alex'])
    end
    assert_equal 1, call_count
    assert_equal ['http://example.org/users/alex'], @captured_args[:selected]
  end

  test 'hydrates each pre-selected ID into a [username, id] tuple' do
    fakes = {
      'http://example.org/users/a' => OpenStruct.new(username: 'alpha', id: 'http://example.org/users/a'),
      'http://example.org/users/b' => OpenStruct.new(username: 'beta',  id: 'http://example.org/users/b')
    }
    LinkedData::Client::Models::User.stub(:get, ->(id, *) { fakes[id] }) do
      user_select_input(name: 'x', selected: fakes.keys)
    end
    assert_equal(
      [['alpha', 'http://example.org/users/a'], ['beta', 'http://example.org/users/b']],
      @captured_args[:values]
    )
  end

  test 'falls back to id as the label when User.get returns nil' do
    LinkedData::Client::Models::User.stub(:get, nil) do
      user_select_input(name: 'x', selected: ['ghost-id'])
    end
    assert_equal [['ghost-id', 'ghost-id']], @captured_args[:values]
  end

  test 'sets remote_url to /accounts/search.json' do
    LinkedData::Client::Models::User.stub(:get, nil) do
      user_select_input(name: 'x', selected: [])
    end
    assert_equal '/accounts/search.json', @captured_args[:remote_url]
  end

  test 'defaults to multiple: true so the resulting select submits an array' do
    LinkedData::Client::Models::User.stub(:get, nil) do
      user_select_input(name: 'x', selected: [])
    end
    assert_equal true, @captured_args[:multiple]
  end

  test 'passes through name, label, and required to select_input' do
    LinkedData::Client::Models::User.stub(:get, nil) do
      user_select_input(name: 'ontology[acl]', label: 'Accounts allowed', selected: [], required: true)
    end
    assert_equal 'ontology[acl]', @captured_args[:name]
    assert_equal 'Accounts allowed', @captured_args[:label]
    assert_equal true, @captured_args[:required]
  end
end
