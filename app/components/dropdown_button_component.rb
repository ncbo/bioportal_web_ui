# frozen_string_literal: true

class DropdownButtonComponent < ViewComponent::Base

  renders_one :header
  renders_many :sections, DropdownSectionButtonComponent

  def initialize(css_class: '')
    super()
    @component_classes = css_class
  end
end
