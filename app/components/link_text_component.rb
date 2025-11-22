# frozen_string_literal: true

class LinkTextComponent < ViewComponent::Base
  include InternationalisationHelper

  def initialize(text:, icon: nil, target: nil)
    @text = text
    @icon = icon
    @target = target
  end

  def before_render
    @upload_mapppings_label = I18n.t('mappings.upload_mappings')
  end

  def call
    svg_icon = !@icon&.empty? ? inline_svg(@icon, width: '14px', height: '14px') : ''
    extra_span = @text == @upload_mapppings_label ? '' : "<span class='mx-1'>#{svg_icon}</span>"
    "#{@text}#{extra_span}".html_safe
  end
end
