# frozen_string_literal: true

class TabsContainerComponent < ViewComponent::Base

  renders_many :items, TabItemComponent
  renders_many :item_contents
  renders_one :pinned_right

  def initialize(id: '', url_parameter: nil, type: 'primary')
    super
    @url_parameter = url_parameter
    @type = type
    @id = id
  end

  def container_class
    case @type
    when 'primary'
      'tabs-container'
    when 'outline'
      'tabs-container outline-tabs'
    when 'pill'
      'pill-tabs-container'
    else
      'tabs-container'
    end
  end

  def item_target(item)
    "##{@id}#{item.target_id}"
  end

  def item_content_id(item)
    @id + item.target_id
  end

  def tabs_container_data(item)
    {
      'bs-toggle': 'tab',
      'bs-target': item_target(item),
      'tab-id': item.id,
      'tab-title': item.page_name,
      'url-parameter': @url_parameter,
      action: 'click->tabs-container#selectTab'
    }
  end
end
