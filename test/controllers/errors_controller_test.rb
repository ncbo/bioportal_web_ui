# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'ostruct'

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @log_output = StringIO.new
    logger = ActiveSupport::Logger.new(@log_output)
    logger.level = Logger::INFO

    # Exercise the exception middleware and error routes as deployed environments do.
    # Rails copies these settings into each request, overriding per-request env values.
    settings = {
      'action_dispatch.show_exceptions' => :all,
      'action_dispatch.show_detailed_exceptions' => false,
      'action_dispatch.log_rescued_responses' => false,
      'action_dispatch.logger' => logger
    }
    @original_env = Rails.application.env_config.slice(*settings.keys)
    Rails.application.env_config.merge!(settings)
    @original_rails_logger = Rails.logger
    @original_controller_logger = ActionController::Base.logger
    Rails.logger = ActionController::Base.logger = logger
  end

  teardown do
    Rails.application.env_config.merge!(@original_env)
    Rails.logger = @original_rails_logger
    ActionController::Base.logger = @original_controller_logger
  end

  test 'routing errors retain HTML and request logs without an exception report' do
    get '/missing-error-test-path', headers: { 'Accept' => 'text/html' }

    assert_response :not_found
    assert_equal 'text/html', response.media_type
    assert_includes response.body, '<html'
    assert_includes @log_output.string, 'Started GET'
    assert_includes @log_output.string, 'Completed 404 Not Found'
    refute_includes @log_output.string, 'ActionController::RoutingError'
  end

  test 'wildcard requests still receive an HTML error page' do
    get '/missing-error-test-path', headers: { 'Accept' => '*/*' }

    assert_response :not_found
    assert_equal 'text/html', response.media_type
  end

  { png: 'image/png', json: 'application/json', xml: 'application/xml' }.each do |extension, mime|
    test "missing #{extension} resources return plain text 404 without a failsafe error" do
      assert_no_failsafe do
        get "/missing-error-test-path.#{extension}", headers: { 'Accept' => mime }
      end

      assert_response :not_found
      assert_equal 'text/plain', response.media_type
      assert_equal 'Not Found', response.body
      refute_includes @log_output.string, 'ActionController::RoutingError'
    end

    test "unexpected failures requested as #{extension} retain their status and diagnostics" do
      failure = ->(*) { raise 'Unexpected error regression test' }
      assert_no_failsafe do
        LinkedData::Client::Models::Ontology.stub(:find_by_acronym, failure) do
          get ontology_path('ERROR-TEST'), headers: { 'Accept' => mime }
        end
      end

      assert_response :internal_server_error
      assert_equal 'text/plain', response.media_type
      assert_equal 'Internal Server Error', response.body
      assert_includes @log_output.string, 'RuntimeError (Unexpected error regression test)'
      assert_includes @log_output.string, 'app/controllers/ontologies_controller.rb'
    end
  end

  test 'browser accept headers on a PNG path do not cause a missing template error' do
    assert_no_failsafe do
      get '/missing-error-test-path.png', headers: {
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    end

    assert_response :not_found
    assert_equal 'text/plain', response.media_type
  end

  test 'missing ontologies retain their 404 response without an exception report' do
    LinkedData::Client::Models::Ontology.stub(:find_by_acronym, []) do
      get ontology_path('ERROR-TEST')
    end

    assert_response :not_found
    assert_equal 'text/html', response.media_type
    assert_includes @log_output.string, 'Completed 404 Not Found'
    refute_includes @log_output.string, 'ActiveRecord::RecordNotFound'
  end

  { html: 'text/html', json: 'application/json' }.each do |format, mime|
    test "access denied retains its #{format} response without an exception report" do
      inaccessible_ontology = OpenStruct.new(errors: ['Access denied'], status: 403)
      assert_no_failsafe do
        LinkedData::Client::Models::Ontology.stub(:find_by_acronym, [inaccessible_ontology]) do
          get ontology_path('PRIVATE'), headers: { 'Accept' => mime }
        end
      end

      assert_response :forbidden
      assert_equal(format == :html ? 'text/html' : 'text/plain', response.media_type)
      assert_includes response.body, 'You do not have permission to access ontology PRIVATE.'
      refute_includes @log_output.string, 'OntologyAccessDeniedError'
    end
  end

  test 'HTML server errors retain the error page and exception diagnostics' do
    failure = ->(*) { raise 'Unexpected error regression test' }
    LinkedData::Client::Models::Ontology.stub(:find_by_acronym, failure) do
      get ontology_path('ERROR-TEST')
    end

    assert_response :internal_server_error
    assert_equal 'text/html', response.media_type
    refute_includes response.body, 'Unexpected error regression test'
    assert_includes @log_output.string, 'RuntimeError (Unexpected error regression test)'
    assert_includes @log_output.string, 'app/controllers/ontologies_controller.rb'
  end

  private

  def assert_no_failsafe
    _stdout, stderr = capture_io { yield }
    assert_empty stderr, 'Error rendering should not invoke the failsafe response'
  end
end
