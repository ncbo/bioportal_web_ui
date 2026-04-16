class VirtualApplianceController < ApplicationController
  layout 'ontology'
  before_action :require_login

  def index
    @user = session[:user]
    @va_users = VirtualApplianceUser.order(:user_id)
  end

  def create
    user = LinkedData::Client::Models::User.find_by_username(params[:appliance_user][:user_id]).first

    if user.nil?
      flash[:error] = "Problem adding account <strong>#{params[:appliance_user][:user_id]}</strong>: account does not exist".html_safe
      redirect_to action: 'index' and return
    end

    @new_user = VirtualApplianceUser.where(user_id: user.id)
    if @new_user.nil? || @new_user.empty?
      @new_user = VirtualApplianceUser.new
      @new_user.user_id = user.id
      @new_user.save
    end

    redirect_to :action => 'index'
  end

  private

  def require_login
    return if session[:user]

    flash[:error] = 'You must be logged in to access this section'
    redirect_to login_index_path(redirect: virtual_appliance_index_path)
  end
end
