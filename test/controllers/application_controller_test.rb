# frozen_string_literal: true

require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'should show home page' do
    get ''
    assert_response :success
  end

  test 'should show projects page' do
    get '/projects'
    assert_response :success
  end

  test 'should show annotator page' do
    get '/annotator'
    assert_response :success
  end

  test 'should show recommender page' do
    get '/recommender'
    assert_response :success
  end

  test 'should show mapping page' do
    get '/mappings'
    assert_response :success
  end

  test 'should show feedback page' do
    get '/feedback'
    assert_response :success
  end
end
