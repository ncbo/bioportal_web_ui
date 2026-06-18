# frozen_string_literal: true

# Generic, reusable **carousel / slider** built with ViewComponent + Stimulus.
#
# It wraps any number of *slides* and shows one at a time, with **Previous /
# Next** navigation. It is generic: a slide can hold anything (text, an image,
# another component). For example it is used to display multiple ontology
# depictions, or the fairness assessment charts.
#
# ## Usage
#
# ```haml
# = render CarouselComponent.new do |c|
#   - @items.each do |item|
#     - c.slide { render SomeComponent.new(item) }
# ```
#
# ## Options
#
# | Option   | Type    | Default | Description                                              |
# |----------|---------|---------|----------------------------------------------------------|
# | `images` | Boolean | `false` | Adds the `carousel--images` modifier (image styling).    |
# | `loop`   | Boolean | `false` | When `true`, navigation wraps around (last → first).     |
#
# Slides are provided through the **`slide` slot** (`renders_many :slides`).
# With `loop: false` the *Previous* button is disabled on the first slide and
# *Next* on the last one.
#
# The behaviour lives in the `carousel` Stimulus controller; the
# `fairness-carousel` controller extends it with custom button selectors.
class CarouselComponentPreview < ViewComponent::Preview
  layout 'component_preview_not_centred'

  SLIDE = ->(label, bg = '#eef2f8') do
    %(<div style="padding:3rem;text-align:center;font-weight:600;background:#{bg}">#{label}</div>).html_safe
  end

  # Basic carousel with a few text slides.
  # *Previous* is disabled on the first slide.
  def default
    render CarouselComponent.new do |c|
      4.times { |i| c.slide { SLIDE.call("Slide #{i + 1}") } }
    end
  end

  # @label With loop
  # With `loop: true`, *Next* on the last slide goes back to the first
  # (and *Previous* on the first goes to the last). No button is ever disabled.
  def with_loop
    render CarouselComponent.new(loop: true) do |c|
      3.times { |i| c.slide { SLIDE.call("Slide #{i + 1}", '#eef7ee') } }
    end
  end

  # @label Images mode
  # `images: true` applies the image-oriented styling
  # (this is how ontology depictions are shown).
  def images
    render CarouselComponent.new(images: true) do |c|
      3.times { c.slide { render Display::ImageComponent.new(src: 'empty-box.svg') } }
    end
  end

  # A single slide: both arrows are disabled (nothing to navigate to).
  def single_slide
    render CarouselComponent.new do |c|
      c.slide { SLIDE.call('Only slide') }
    end
  end

  # @label Playground
  # @param images toggle
  # @param loop toggle
  # @param slides number
  def playground(images: false, loop: false, slides: 4)
    render CarouselComponent.new(images: images, loop: loop) do |c|
      slides.to_i.times { |i| c.slide { SLIDE.call("Slide #{i + 1}") } }
    end
  end
end
