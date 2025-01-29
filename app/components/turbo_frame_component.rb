# frozen_string_literal: true

class TurboFrameComponent < ViewComponent::Base
  include Turbo::FramesHelper

  renders_one :loader

  def initialize(id:, src: '', **html_options)
    @id = id
    @src = src
    @html_options = html_options
  end

  def turbo_frame_html_options
    out = {
      data: {
        'turbo-frame-error-target': 'frame',
        action: 'turbo:before-fetch-response->turbo-frame-error#showError turbo:before-fetch-request->turbo-frame-error#hideError'
      },
      class: 'w-100'
    }
    if @html_options.nil?
      @html_options = out
    else
      @html_options[:data] ||= {}
      @html_options[:data].merge!(out[:data]) do |_, old, new|
        "#{old} #{new}"
      end
      @html_options[:class] ||= ''
      @html_options[:class] += " #{out[:class]}"
    end

    if @src && !@src.empty?
      @html_options[:src] = @src
    end

    @html_options
  end
end
