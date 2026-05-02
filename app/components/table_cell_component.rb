# frozen_string_literal: true

class TableCellComponent < ViewComponent::Base

  def initialize(width: nil, colspan: nil, style: nil, type: 'td')
    super()
    @width = width
    @type = type
    @colspan = colspan
    @style = style
  end

  def call
    options = {}
    options[:width] = @width if @width
    options[:colspan] = @colspan if @colspan
    options[:style] = @style if @style
    content_tag(@type, content&.html_safe, options)
  end
end
