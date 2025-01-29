# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :unescape_id, only: [:edit, :show, :update]
  before_action :verify_owner, only: [:edit, :show]
  before_action :authorize_admin, only: [:index]

  layout :determine_layout

  def index
    @users = LinkedData::Client::Models::User.all
    respond_to do |format|
      format.html
      format.xml { render xml: @users.to_xml }
    end
  end

  def show
    @user = LinkedData::Client::Models::User.get(params[:id], include: 'all')
    @all_ontologies = LinkedData::Client::Models::Ontology.all(ignore_custom_ontologies: true)
    @user_ontologies = @user.customOntology

    # Copied from home controller, account action
    @admin_ontologies = LinkedData::Client::Models::Ontology.where(include_views: true) do |o|
      o.administeredBy.include? @user.id
    end
    @admin_ontologies.sort! { |a, b| a.name.downcase <=> b.name.downcase }

    @user_projects = LinkedData::Client::Models::Project.where do |p|
      p.creator.include? @user.id
    end
    @user_projects.sort! { |a, b| a.name.downcase <=> b.name.downcase }
  end

  def new
    @user = LinkedData::Client::Models::User.new
  end

  def edit
    @user = LinkedData::Client::Models::User.get(params[:id], include: 'all')
  end

  def create
    @errors = validate(user_params)
    @user = LinkedData::Client::Models::User.new(values: user_params)

    if @errors.empty?
      @user_saved = @user.save
      if response_error?(@user_saved)
        @errors = response_errors(@user_saved)
        # @errors = {acronym: "Username already exists, please use another"} if @user_saved.status == 409
        render 'new'
      else
        flash[:notice] = 'Account was successfully created'
        session[:user] = LinkedData::Client::Models::User.authenticate(@user.username, @user.password)
        redirect_to user_path(@user.username)
      end
    else
      render 'new'
    end
  end

  def update
    @user = LinkedData::Client::Models::User.get(params[:id], include: 'all')

    @errors = validate_update(user_params)
    if @errors.empty?
      user_roles = @user.role

      if @user.admin? != (params[:user][:admin].to_i == 1)
        user_roles = update_role(@user)
      end

      @user.update_from_params(user_params.merge!(role: user_roles))
      error_response = @user.update(cache_refresh_all: false)

      if response_error?(error_response)
        @errors = response_errors(error_response)
        # @errors = {acronym: "Username already exists, please use another"} if error_response.status == 409
        render 'edit'
      else
        flash[:notice] = 'Account successfully updated!'

        if session[:user].username == @user.username
          session[:user].update_from_params(user_params)
        end
        redirect_to user_path(@user.username)
      end
    else
      render 'edit'
    end
  end

  def destroy
    response = { errors: String.new(''), success: String.new('') }
    @user = LinkedData::Client::Models::User.get(params[:id])
    if session[:user].admin?
      @user.delete
      response[:success] << 'User deleted successfully '
    else
      response[:errors] << 'Not permitted '
    end

    render json: response
  end

  def custom_ontologies
    @user = LinkedData::Client::Models::User.get(params[:id])

    custom_ontologies = params[:ontology] ? params[:ontology][:ontologyId] : []
    custom_ontologies.reject!(&:blank?)
    @user.update_from_params(customOntology: custom_ontologies)
    response = @user.update

    if response.success?
      updated_user = LinkedData::Client::Models::User.get(@user.id, include: 'customOntology')
      session[:user].update_from_params(customOntology: updated_user.customOntology)
      flash[:notice] = if updated_user.customOntology.empty?
                         'Custom ontology set successfully cleared'
                       else
                         'Custom ontology set successfully saved'
                       end
    else
      flash[:error] = 'Error saving custom ontology set. Please try again.'
    end
    redirect_to user_path(@user.username)
  end

  private

  def user_params
    p = params.require(:user).permit(:firstName, :lastName, :username, :email, :password, :password_confirmation,
                                     :admin, :githubId, :orcidId)
    p.to_h
  end

  def unescape_id
    params[:id] = CGI.unescape(params[:id])
  end

  def verify_owner
    return if current_user_admin?

    user = session[:user]
    return if user&.id == params[:id] || user&.username == params[:id]

    redirect_to login_index_path(redirect: "/accounts/#{params[:id]}")
  end

  def validate(params)
    errors = []
    if params[:email].length < 1 || !params[:email].match(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i)
      errors << 'invalid email address'
    end
    if using_captcha?
      if !verify_recaptcha
        errors << 'reCAPTCHA verification failed, please try again'
      end
    end

    errors
  end

  def validate_update(params)
    errors = []
    if params[:email].length < 1 || !params[:email].match(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i)
      errors << 'invalid email address'
    end
    errors
  end

  def update_role(user)
    user_roles = user.role

    if session[:user].admin?
      user_roles = user_roles.dup
      if user.admin?
        user_roles.map! { |role| role == 'ADMINISTRATOR' ? 'LIBRARIAN' : role }
      else
        user_roles.map! { |role| role == 'LIBRARIAN' ? 'ADMINISTRATOR' : role }
      end
    end

    user_roles
  end
end
