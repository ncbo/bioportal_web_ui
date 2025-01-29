# frozen_string_literal: true

class PasswordsController < ApplicationController
  before_action :require_logged_in_user
  before_action :set_user

  layout :determine_layout

  def edit; end

  def update
    if params[:password] != params[:password_confirmation]
      flash.now[:warning] = 'New password and password confirmation do not match. Please try again.'
      render 'edit'
      return
    end

    response = @user.update(values: { password: params[:password] })
    if response_error?(response)
      @errors = response_errors(response)
      render 'edit'
    else
      flash[:success] = 'Password successfully updated!'
      redirect_to user_path(@user.username)
    end
  end

  private

  def password_params
    p = params.permit(:password, :password_confirmation)
    p.to_h
  end

  def require_logged_in_user
    if session[:user].blank?
      flash[:warning] = 'You must be logged in to access that page'
      redirect_to login_index_path
    end
  end

  def set_user
    @user = session[:user]
  end
end
