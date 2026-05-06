# frozen_string_literal: true
class ListItemsShowMoreComponent < ViewComponent::Base
  renders_many :containers

  def initialize(max_items: 10)
    super()
    @max_items = max_items - 1
  end

end
