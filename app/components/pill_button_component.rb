# frozen_string_literal: true

class PillButtonComponent < ViewComponent::Base

  def initialize(text: nil)
    super()
    @text = text
  end
end
