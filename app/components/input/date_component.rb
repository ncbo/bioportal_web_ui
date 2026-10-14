# frozen_string_literal: true

class Input::DateComponent < Input::InputFieldComponent
  # Use the browser's native date control; values and bounds must be ISO dates.
  def initialize(label: '', name:, value: Date.today, error_message: '', helper_text: '', id: nil, max_date: nil)
    super(label: label, name: name, value: date_value(value),
          error_message: error_message, helper_text: helper_text, id: id, max: date_value(max_date))
  end

  def call
    render Input::InputFieldComponent.new(label: @label, name: @name, value: @value,
                                         error_message: @error_message, helper_text: @helper_text,
                                         type: 'date', id: @id, max: @max)
  end

  private

  def date_value(value)
    return if value.blank?

    date = value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
    date.iso8601
  rescue ArgumentError
    value
  end
end
