# frozen_string_literal: true

class SelectInputComponent < ViewComponent::Base

  def initialize(id:, name:, values:, selected: nil, multiple: false, open_to_add_values: false, required: false, data: {}, placeholder: '', **html_options)
    super()
    @id = id || ''
    @name = name
    @values = values
    @selected = selected
    @multiple = multiple
    @open_to_add_values = open_to_add_values
    @placeholder = placeholder
    @data = data
    @required = required
    @html_options = html_options
  end

  def call
    select_input_tag(@id, @name, @values, @selected, multiple: @multiple, open_to_add_values: @open_to_add_values,
                     placeholder: @placeholder, required: @required)
  end

  private

  def select_input_tag(id, name, values, selected, options = {})
    multiple = options[:multiple] || false
    open_to_add_values = options[:open_to_add_values] || false
    required = options[:required] || false
    placeholder = options[:placeholder] || ''
    data = @data.merge({
                         'select-input-multiple-value': multiple,
                         'select-input-open-add-value': open_to_add_values,
                         'select-input-required-value': required,
                       })
    data[:controller] = "#{data[:controller]} select-input"

    select_html_options = {
      id: "select_#{id}",
      placeholder: placeholder,
      autocomplete: 'off',
      multiple: multiple,
      data: data,
    }.merge(@html_options)

    select_html_options[:style] = "#{select_html_options[:style]}; visibility: hidden"

    select_tag(name, options_for_select(values, selected), select_html_options)

  end
end
