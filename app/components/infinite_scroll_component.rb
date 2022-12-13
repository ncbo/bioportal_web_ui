# frozen_string_literal: true

class InfiniteScrollComponent < ViewComponent::Base
  include Turbo::FramesHelper
  attr_reader :collection
  renders_one :error

  def initialize(id:, collection:, next_url:, current_page:, next_page:, auto_click: false)
    super
    @id = id
    @collection = collection
    @next_url = next_url
    @current_page = current_page
    @next_page = next_page
    @auto_click = auto_click
  end

  def auto_click?
    @auto_click
  end

end
