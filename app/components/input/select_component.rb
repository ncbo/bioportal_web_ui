# frozen_string_literal: true

class Input::SelectComponent < Input::InputFieldComponent

  def initialize(id: nil, label: '', name:, value: [], selected: '', placeholder: '', error_message: '', helper_text: '', multiple: false, open_to_add_values: false, required: false,  data: {}, tooltip: nil, remote_url: nil, remote_query_param: 'q')
    super(label: label, name: name, value: value, placeholder: placeholder, error_message: error_message,
          helper_text: helper_text, data: data, tooltip: tooltip)
    @values = value
    @selected = selected
    @open_to_add_values = open_to_add_values
    @multiple = multiple
    @id = id
    @required = required
    @remote_url = remote_url
    @remote_query_param = remote_query_param
  end

  def call
    render Input::InputFieldComponent.new(name: @name, error_message: @error_message, helper_text: @helper_text, label: @label, tooltip: @tooltip) do
      render SelectInputComponent.new(id: @id, name: @name, values: @values, selected: @selected,
                                      placeholder: @placeholder, required: @required,
                                      multiple: @multiple, open_to_add_values: @open_to_add_values,
                                      remote_url: @remote_url, remote_query_param: @remote_query_param,
                                      data: @data)
    end
  end
end
