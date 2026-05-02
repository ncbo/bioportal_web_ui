# frozen_string_literal: true

class DropdownSectionButtonComponent < ViewComponent::Base

  renders_one :header
  renders_many :items

  def initialize(divide: true, selected_index: nil)
    super()
    @divide = divide
    @selected = selected_index
  end

  def show_divider?
    @divide
  end
end
