# frozen_string_literal: true

class Layout::ProgressPagesComponent < ViewComponent::Base

  renders_many :pages
  def initialize(pages_title: [])
    super()
    @pages_title = pages_title
  end
end
