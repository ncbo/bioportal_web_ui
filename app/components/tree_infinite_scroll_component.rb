# frozen_string_literal: true

# Component for rendering paginated tree data with infinite scroll
class TreeInfiniteScrollComponent < ViewComponent::Base
  attr_reader :collection

  renders_one :error

  # rubocop:disable Metrics/ParameterLists
  def initialize(id:, collection:, next_url:, current_page:, next_page:, auto_click: false)
    super
    @id = id
    @collection = collection
    @next_url = next_url
    @current_page = current_page
    @next_page = next_page
    @auto_click = auto_click
  end
  # rubocop:enable Metrics/ParameterLists

  def auto_click?
    @auto_click
  end
end
