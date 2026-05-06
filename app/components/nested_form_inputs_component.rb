# frozen_string_literal: true

class NestedFormInputsComponent < ViewComponent::Base

  renders_one :template
  renders_one :header
  renders_many :rows
  renders_one :empty_state

  def initialize(object_name: '', default_empty_row: false)
    super()
    @object_name = object_name
    @default_row = default_empty_row
  end
end
