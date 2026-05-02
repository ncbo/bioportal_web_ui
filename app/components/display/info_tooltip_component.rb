# frozen_string_literal: true

class Display::InfoTooltipComponent < ViewComponent::Base

  def initialize(text: nil , icon: "info.svg", interactive: true)
    super()
    @text = text
    @icon = icon
    @interactive = interactive
  end
  def call
    content_tag(:div, data:{controller:'tooltip', 'tooltip-interactive-value': @interactive}, title: @text, style: 'display: inline-block;') do
      if content
        content
      else
        helpers.inline_svg_tag "icons/#{@icon}", width: '20', height: '20'
      end
    end
  end

end
