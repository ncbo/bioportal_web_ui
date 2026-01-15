# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base

  renders_many :cells, TableCellComponent

  def initialize(id: '', class_css: '')
    super
    @id = id
    @class_css = class_css
  end

  def create(*array, &block)
    array.each do |key_value|
      key, value = key_value.to_a.first
      with_cell(type: key) { value&.to_s }
    end
    block.call(self) if block_given?
  end

  def th(width: nil, colspan: nil, &block)
    with_cell(type: 'th', width: width, colspan: colspan, &block)
  end

  def td(width: nil, colspan: nil, style: nil, &block)
    with_cell(type: 'td', width: width, colspan: colspan, style: style, &block)
  end
end
