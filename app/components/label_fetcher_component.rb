# frozen_string_literal: true
class LabelFetcherComponent < ViewComponent::Base
  include UrlsHelper, Turbo::FramesHelper, ModalHelper

  def initialize(id:, label: nil, link: nil, ajax_src: nil, open_in_modal: false, target: nil, external: false)
    super
    @id = id
    @link = link
    @ajax_src = ajax_src
    @open_in_modal = open_in_modal
    @target = target
    @external = external
    @label = label

    if external_link?
      @link = id
      @target ||= '_blank'
    else
      @target ||= '_top'
    end

  end

  def external_link?
    (@label.nil? || @label.eql?(@id)) && @external
  end

  def label_fetcher_container(&block)
    id = "#{escape(@id)}_label"
    if @ajax_src
      render(TurboFrameComponent.new(id: id, src: "#{@ajax_src}&target=#{@target}", loading: 'lazy')) do |t|
        t.with_loader do
          render ChipButtonComponent.new(url: @id, text: "#{@id} #{render(LoaderComponent.new(small: true))}", type: 'clickable', target: '_blank')
        end

        t.with_error do
          capture(&block)
        end
      end
    else
      turbo_frame_tag(id) do
        capture(&block)
      end
    end

  end

  def link_with_icon
    if external_link?
      ExternalLinkTextComponent.new(text: @label).call
    else
      InternalLinkTextComponent.new(text: @label).call
    end
  end
end
