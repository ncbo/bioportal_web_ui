# frozen_string_literal: true

class LoginController < ApplicationController
  layout :determine_layout

  def index
    # Sets the redirect properties
    if params[:redirect]
      # Get the original, encoded redirect
      uri = URI.parse(request.url)
      orig_params = Hash[uri.query.split("&").map { |e| e.split("=", 2) }].symbolize_keys
      session[:redirect] = orig_params[:redirect]
    else
      session[:redirect] = request.referer
    end
  end

  # logs in a user
  def create
    @errors = validate(params[:user])
    if @errors.empty?
      logged_in_user = LinkedData::Client::Models::User.authenticate(params[:user][:username], params[:user][:password])
      if logged_in_user && !logged_in_user.errors
        login(logged_in_user)
        redirect = '/'

        if session[:redirect]
          redirect = CGI.unescape(session[:redirect])
        end

        redirect_to redirect
      else
        @errors << 'Invalid account name/password combination'
        render 'index'
      end
    else
      render 'index'
    end
  end

  # Login as the provided username (only for admin users)
  def login_as
    unless session[:user] && session[:user].admin?
      redirect_to '/'
      return
    end

    user = params[:login_as]
    new_user = LinkedData::Client::Models::User.find_by_username(user).first

    if new_user
      session[:admin_user] = session[:user]
      session[:user] = new_user
      session[:user].apikey = session[:admin_user].apikey
    end

    # redirect_to request.referer rescue redirect_to "/"
    redirect_to '/'
  end

  # logs out a user
  def destroy
    if session[:admin_user]
      old_user = session[:user]
      session[:user] = session[:admin_user]
      session.delete(:admin_user)
      flash[:success] = "Logged out <b>#{old_user.username}</b>, returned to <b>#{session[:user].username}</b>".html_safe
    else
      session[:user] = nil
      flash[:success] = 'You have successfully logged out'
    end
    redirect_to request.referer || '/'
  end

  def lost_password; end

  # Sends a new password to the user
  def send_pass
    username = params[:user][:account_name]
    email = params[:user][:email]
    resp = LinkedData::Client::HTTP.post('/users/create_reset_password_token', { username: username, email: email })

    if resp.nil?
      redirect_to login_index_path, notice: 'Please check your email for a message with reset instructions'
    else
      flash[:notice] = "#{resp.errors.first}. Please try again."
      redirect_to '/lost_pass'
    end
  end

  def reset_password
    username = params[:un]
    email = params[:em]
    token = params[:tk]
    @user = LinkedData::Client::HTTP.post('/users/reset_password', { username: username, email: email, token: token })
    if @user.is_a?(LinkedData::Client::Models::User)
      login(@user)
      render 'passwords/edit'
    else
      flash[:notice] = "#{@user.errors.first}. Please reset your password again."
      redirect_to '/lost_pass'
    end
  end

  private

  def login(user)
    return unless user

    session[:user] = user
    custom_ontologies_text = session[:user].customOntology && !session[:user].customOntology.empty? ? "The display is now based on your <a href='/account#custom_ontology_set'>Custom Ontology Set</a>." : ""
    notice = "Welcome <b>" + user.username.to_s + "</b>! " + custom_ontologies_text
    flash[:success] = notice.html_safe
  end

  def validate(params)
    errors = []

    if params[:username].empty?
      errors << 'Please enter an account name'
    end
    if params[:password].empty?
      errors << 'Please enter a password'
    end

    errors
  end
end
