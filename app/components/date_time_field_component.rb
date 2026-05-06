# frozen_string_literal: true

class DateTimeFieldComponent < ViewComponent::Base

  def initialize(value: , format: :monthfull_day_year)
    super()
    @value = value
    @format = format
  end

  def call
    l(Date.parse(@value), format: @format.to_sym).html_safe if @value
  end

end
