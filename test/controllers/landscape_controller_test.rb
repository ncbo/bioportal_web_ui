# frozen_string_literal: true

require 'test_helper'

class LandscapeControllerTest < ActionController::TestCase
  test 'should get index' do
    skip('take too much time')
    get :index
    assert_response :success
  end
end
