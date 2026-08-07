# frozen_string_literal: true

class CookiesController < ApplicationController
  def index; end

  def acknowledge
    cookies[:cookie_notice_ack] = { value: 'true', expires: 1.year.from_now }
    render turbo_stream: turbo_stream.remove(:cookie_notice)
  end
end
