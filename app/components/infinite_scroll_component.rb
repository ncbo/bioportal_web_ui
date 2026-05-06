# frozen_string_literal: true

class InfiniteScrollComponent < ViewComponent::Base
  include Turbo::FramesHelper
  attr_reader :collection

  renders_one :error
  renders_one :loader

  def initialize(id:, collection:, next_url:, current_page:, next_page:)
    super()
    @id = id
    @collection = collection
    @next_url = next_url
    @current_page = current_page
    @next_page = next_page

  end

end
