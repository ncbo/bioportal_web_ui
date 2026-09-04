class ErrorsController < ApplicationController
  layout :determine_layout

  skip_before_action :domain_ontology_set, :init_trial_license
  before_action :set_error_page_defaults

  def forbidden
    @error_message = request.env['action_dispatch.exception']&.message.presence ||
                     t('application.forbidden_message')

    if request.xhr?
      render plain: @error_message, status: :forbidden
    else
      render status: :forbidden
    end
  end

  def not_found
    render status: 404
  end

  def internal_server_error
    render status: 500
  end

  private

  def set_error_page_defaults
    @subdomain_filter = { active: false, name: '', acronym: '' }
  end
end
