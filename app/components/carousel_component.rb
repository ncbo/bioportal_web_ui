# frozen_string_literal: true

class CarouselComponent < ViewComponent::Base
  renders_many :slides

  def initialize(images: false, loop: false)
    super
    @images = images
    @loop = loop
  end

  def css_class
    @images ? 'carousel carousel--images' : 'carousel'
  end
end
