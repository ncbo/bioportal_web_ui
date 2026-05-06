# frozen_string_literal: true

class Display::HeaderComponent < ViewComponent::Base

  include ComponentsHelper


  def initialize(text: nil, tooltip: nil)
    super()
    @text = text
    @info = tooltip
  end

  def call
    content_tag(:div, class: 'header-component') do
      out = content_tag(:p, content&.html_safe || @text)
      if @info && !@info.empty?
        out = out + info_tooltip(content_tag(:div, @info, style: 'max-width: 300px'))
      end
      out
    end
  end

end
