# frozen_string_literal: true

class TabsContainerComponent < ViewComponent::Base

  renders_many :items, TabItemComponent
  renders_many :item_contents
  renders_one :pinned_right

  # merge_url_params: when true, selecting a tab MERGES its url_parameter into the
  # current query string (keeping the other params); when false (the default) it
  # replaces the query string with just this tab's param. Merge is for tabs that
  # coexist with other state — e.g. the concept views, which must keep `conceptid`.
  # Replace is for tabs that own the query string — e.g. the top-level `p` sections.
  def initialize(id: '', url_parameter: nil, type: 'primary', merge_url_params: false)
    super()
    @url_parameter = url_parameter
    @type = type
    @id = id
    @merge_url_params = merge_url_params
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
      # Emit an explicit string, not a Ruby boolean: Rails renders a `true` data value
      # as a valueless attribute (data-url-merge=""), which the controller reads as ""
      # and would treat as "replace". "true"/"false" makes the intent unambiguous.
      'url-merge': @merge_url_params.to_s,
      action: 'click->tabs-container#selectTab'
    }
  end
end
