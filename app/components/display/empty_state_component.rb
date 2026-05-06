# frozen_string_literal: true

class Display::EmptyStateComponent < ViewComponent::Base

  def initialize(text: t('no_result_was_found'))
    @text = text
  end


  def call
    content_tag(:div, class:'browse-empty-illustration') do
      helpers.inline_svg_tag('empty-box.svg') +
      content_tag(:p, @text)
    end.html_safe
  end
end
