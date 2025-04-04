# frozen_string_literal: true

class AdminController < ApplicationController
  layout :determine_layout
  before_action :cache_setup

  DEBUG_BLACKLIST = [:"$,", :$ADDITIONAL_ONTOLOGY_DETAILS, :$rdebug_state, :$PROGRAM_NAME, :$LOADED_FEATURES, :$KCODE, :$-i, :$rails_rake_task, :$$, :$gems_build_rake_task, :$daemons_stop_proc, :$VERBOSE, :$DAEMONS_ARGV, :$daemons_sigterm, :$DEBUG_BEFORE, :$stdout, :$-0, :$-l, :$-I, :$DEBUG, :$', :$gems_rake_task, :$_, :$CODERAY_DEBUG, :$-F, :$", :$0, :$=, :$FILENAME, :$?, :$!, :$rdebug_in_irb, :$-K, :$TESTING, :$fileutils_rb_have_lchmod, :$EMAIL_EXCEPTIONS, :$binding, :$-v, :$>, :$SAFE, :$/, :$fileutils_rb_have_lchown, :$-p, :$-W, :$:, :$__dbg_interface, :$stderr, :$\, :$&, :$<, :$debug, :$;, :$~, :$-a, :$DEBUG_RDOC, :$CGI_ENV, :$LOAD_PATH, :$-d, :$*, :$., :$-w, :$+, :$@, :$`, :$stdin, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
  ADMIN_URL = "#{LinkedData::Client.settings.rest_url}/admin/"
  ONTOLOGIES_URL = "#{ADMIN_URL}ontologies_report"
  USERS_URL = "#{LinkedData::Client.settings.rest_url}/users"
  ONTOLOGY_URL = lambda { |acronym| "#{ADMIN_URL}ontologies/#{acronym}" }
  PARSE_LOG_URL = lambda { |acronym| "#{ONTOLOGY_URL.call(acronym)}/log" }
  REPORT_NEVER_GENERATED = 'NEVER GENERATED'

  def index
    @users = LinkedData::Client::Models::User.all

    if session[:user].nil? || !session[:user].admin?
      redirect_to controller: 'login', action: 'index', redirect: '/admin'
    else
      update_info(render_response: false)
      render action: 'index'
    end
  end

  def update_info(render_response: true)
    response = { update_info: {}, errors: '', success: '', notices: '' }

    begin
      json = LinkedData::Client::HTTP.get("#{ADMIN_URL}update_info", params, raw: true)
      update_info = JSON.parse(json)

      # Always store @update_info, even if an error is present
      @update_info = update_info.symbolize_keys

      # Only treat it as a blocking error if no useful data exists
      if @update_info[:error]
        # Log or surface the error, but don't block downstream access to valid fields
        response[:errors] = @update_info[:error]
      else
        response[:success] = 'Update info successfully retrieved'
      end

      response[:notices] = update_info['notes'] if @update_info[:notes]
      response[:update_info] = @update_info
    rescue StandardError => e
      @update_info = {}
      response[:errors] = "Problem retrieving update info - #{e.message}"
    end

    render json: response if render_response
  end

  def update_check_enabled
    enabled = LinkedData::Client::HTTP.get("#{ADMIN_URL}update_check_enabled", {}, raw: false)
    render json: enabled
  end

  def submissions
    @submissions = nil
    @acronym = params['acronym']
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params['acronym']).first
    begin
      submissions = @ontology.explore.submissions
      @submissions = submissions.sort { |a, b| b.submissionId <=> a.submissionId }
    rescue
      @submissions = []
    end
    render partial: 'layouts/ontology_report_submissions'
  end

  def parse_log
    @acronym = params['acronym']
    @parse_log = LinkedData::Client::HTTP.get(PARSE_LOG_URL.call(params['acronym']), {}, raw: false)
    ontologies_report = _ontologies_report
    ontology = ontologies_report[:ontologies][params['acronym'].to_sym]
    @log_file_path = ''

    if ontology
      full_log_file_path = ontology[:logFilePath]
      @log_file_path = /#{params["acronym"]}\/\d+\/[-a-zA-Z0-9_]+\.log$/.match(full_log_file_path)
    else
      @parse_log = "No record exists for ontology #{params["acronym"]}"
      @log_file_path = 'None'
    end
    render action: 'parse_log'
  end

  def clearcache
    response = { errors: '', success: '' }

    if @cache.respond_to?(:flush_all)
      begin
        @cache.flush_all
        response[:success] = 'UI cache successfully flushed'
      rescue StandardError => e
        response[:errors] = "Problem flushing the UI cache - #{e.class}: #{e.message}"
      end
    else
      response[:errors] = "The UI cache does not respond to the 'flush_all' command"
    end
    render json: response
  end

  def resetcache
    response = { errors: '', success: '' }

    if @cache.respond_to?(:reset)
      begin
        @cache.reset
        response[:success] = 'UI cache connection successfully reset'
      rescue StandardError => e
        response[:errors] = "Problem resetting the UI cache connection - #{e.message}"
      end
    else
      response[:errors] = "The UI cache does not respond to the 'reset' command"
    end
    render json: response
  end

  def clear_goo_cache
    response = { errors: '', success: '' }

    begin
      LinkedData::Client::HTTP.post("#{ADMIN_URL}clear_goo_cache", params, raw: true)
      response[:success] = 'Goo cache successfully flushed'
    rescue StandardError => e
      response[:errors] = "Problem flushing the Goo cache - #{e.class}: #{e.message}"
    end
    render json: response
  end

  def clear_http_cache
    response = { errors: '', success: '' }

    begin
      LinkedData::Client::HTTP.post("#{ADMIN_URL}clear_http_cache", params, raw: true)
      response[:success] = 'HTTP cache successfully flushed'
    rescue StandardError => e
      response[:errors] = "Problem flushing the HTTP cache - #{e.class}: #{e.message}"
    end
    render json: response
  end

  def ontologies_report
    response = _ontologies_report
    render json: response
  end

  def refresh_ontologies_report
    response = { errors: '', success: '' }

    begin
      response_raw = LinkedData::Client::HTTP.post(ONTOLOGIES_URL, params, raw: true)
      response_json = JSON.parse(response_raw, symbolize_names: true)

      if response_json[:errors]
        _process_errors(response_json[:errors], response, true)
      else
        response = response_json

        if params['ontologies'].blank?
          response[:success] = 'Refresh of ontologies report started successfully'
        else
          ontologies = params['ontologies'].split(',').map { |o| o.strip }
          response[:success] = "Refresh of report for ontologies: #{ontologies.join(', ')} started successfully"
        end
      end
    rescue StandardError => e
      response[:errors] = "Problem refreshing report - #{e.class}: #{e.message}"
    end
    render json: response
  end

  def process_ontologies
    _process_ontologies('enqued for processing', 'processing', :_process_ontology)
  end

  def delete_ontologies
    _process_ontologies('and all its artifacts deleted', 'deleting', :_delete_ontology)
  end

  def delete_submission
    response = { errors: '', success: '' }

    begin
      ont = params['acronym']
      ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ont).first

      if ontology
        submissions = ontology.explore.submissions
        submission = submissions.select { |o| o.submissionId == params['id'].to_i }.first

        if submission
          error_response = submission.delete

          if response_error?(error_response)
            errors = response_errors(error_response) # see application_controller::response_errors
            _process_errors(errors, response, true)
          else
            response[:success] += "Submission #{params["id"]} for ontology #{ont} was deleted successfully"
          end
        else
          response[:errors] += "Submission #{params["id"]} for ontology #{ont} was not found in the system"
        end
      else
        response[:errors] += "Ontology #{ont} was not found in the system"
      end
    rescue StandardError => e
      response[:errors] += "Problem deleting submission #{params["id"]} for ontology #{ont} - #{e.class}: #{e.message}"
    end
    render json: response
  end

  def users
    response = _users
    render json: response
  end

  private

  def cache_setup
    @cache = Rails.cache.instance_variable_get("@data")
  end

  def _ontologies_report
    response = { ontologies: {}, report_date_generated: REPORT_NEVER_GENERATED, errors: '', success: '' }
    start = Time.now

    begin
      ontologies_data = LinkedData::Client::HTTP.get(ONTOLOGIES_URL, {}, raw: true)
      ontologies_data_parsed = JSON.parse(ontologies_data, symbolize_names: true)

      if ontologies_data_parsed[:errors]
        _process_errors(ontologies_data_parsed[:errors], response, true)
      else
        response.merge!(ontologies_data_parsed)
        response[:success] = "Report successfully regenerated on #{ontologies_data_parsed[:report_date_generated]}"
        Log.add :debug, "Ontologies Report - retrieved #{response[:ontologies].length} ontologies in #{Time.now - start}s"
      end
    rescue StandardError => e
      response[:errors] = "Problem retrieving ontologies report - #{e.message}"
    end
    response
  end

  def _process_errors(errors, response, remove_trailing_comma = true)
    if errors.is_a?(Hash)
      errors.each do |_, v|
        if v.is_a?(Array)
          response[:errors] += v.join(', ')
          response[:errors] += ', '
        else
          response[:errors] += "#{v}, "
        end
      end
    elsif errors.is_a?(Array)
      errors.each { |err| response[:errors] += "#{err}, " }
    end
    response[:errors] = response[:errors][0...-2] if remove_trailing_comma
  end

  def _delete_ontology(ontology, _params)
    error_response = ontology.delete
    error_response
  end

  def _process_ontology(ontology, params)
    LinkedData::Client::HTTP.put(ONTOLOGY_URL.call(ontology.acronym), params)
  end

  def _process_ontologies(success_keyword, error_keyword, process_proc)
    response = { errors: '', success: '' }

    if params['ontologies'].blank?
      response[:errors] = "No ontologies parameter passed. Syntax: ?ontologies=ONT1,ONT2,...,ONTN"
    else
      ontologies = params['ontologies'].split(',').map { |o| o.strip }

      ontologies.each do |ont|
        begin
          ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ont).first

          if ontology
            error_response = self.send(process_proc, ontology, params)
            if response_error?(error_response)
              errors = response_errors(error_response) # see application_controller::response_errors
              _process_errors(errors, response, false)
            else
              response[:success] += "Ontology #{ont} #{success_keyword} successfully, "
            end
          else
            response[:errors] += "Ontology #{ont} was not found in the system, "
          end
        rescue StandardError => e
          response[:errors] += "Problem #{error_keyword} ontology #{ont} - #{e.class}: #{e.message}, "
        end
      end
      response[:success] = response[:success][0...-2] unless response[:success].empty?
      response[:errors] = response[:errors][0...-2] unless response[:errors].empty?
    end
    render json: response
  end

  def _users
    response = { users: {}, errors: '', success: '' }
    start = Time.now
    begin
      response[:users] = JSON.parse(LinkedData::Client::HTTP.get(USERS_URL, { include: 'all' }, raw: true))

      response[:success] = "users successfully retrieved in  #{Time.now - start}s"
      Log.add :debug, "Users - retrieved #{response[:users].length} users in #{Time.now - start}s"
    rescue StandardError => e
      response[:errors] = "Problem retrieving users  - #{e.message}"
    end
    response
  end
end
