module ModalHelper

  def link_to_modal(name, options = nil, html_options = nil, &block)
    html_options = modal_controller_data(html_options)
    if name.nil?
      link_to(options, html_options, &block)
    else
      link_to(render(PopupLinkTextComponent.new(text: name)), options, html_options)
    end
  end


  def modal_frame_container(id = 'application_modal')
    render TurboModalComponent.new(id: id)
  end

  def modal_frame_id(id = 'application_modal')
    "#{id}_content"
  end

  def render_in_modal(id = modal_frame_id, &block)
    render TurboFrameComponent.new(id: id) do
      capture(&block).html_safe if block_given?
    end
  end

  private

  def modal_controller_data(html_options)
    new_data = {
      controller: 'show-modal', turbo: true,
      turbo_frame: 'application_modal_content',
      action: 'click->show-modal#show'
    }

    html_options ||= {data: {}}
    html_options[:data].merge!(new_data) do |_, old, new|
      "#{old} #{new}"
    end
    html_options
  end
end
