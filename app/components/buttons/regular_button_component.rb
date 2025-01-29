class Buttons::RegularButtonComponent < ViewComponent::Base
  renders_one :icon_left
  renders_one :icon_right

  def initialize(id: , value:, variant: "primary", color: "normal", href: "", size: "normal", state: "animate", type: 'button', target: nil)
    @id = id
    @value = value
    @variant = variant
    @color = color
    @href = href
    @size = size
    @state = state
    @type = type
    @target = target
  end

  def button_label
    hide_icon_left = icon_left == nil ? "hide" : " "
    hide_icon_right = icon_right == nil ? "hide" : " "
    content_tag(:span, icon_left, class: "#{@variant}-button-icon left-button-icon #{hide_icon_left}") + content_tag(:div, @value)  + content_tag(:span, icon_right, class: "#{@variant}-button-icon right-button-icon #{hide_icon_right}")
  end

  def button_elem
    slim_class = @size == "slim" ? "slim " : " "
    danger_class = @color == "danger" ? "danger-button " : " "
    warning_class = @color == "warning" ? "warning-button " : " "
    disabled_class = @state == "disabled" ? "disabled-button " : " "
    class_style = "#{@variant}-button regular-button " + danger_class + warning_class + disabled_class + slim_class
    on_click_event =  load_animation? ?  "displayAnimation(this, '#{@id}-loading-animation')" : ''

    if link?
      link_to(@href, class: class_style, onclick: on_click_event, id: @id, target: @target) do
        button_label
      end
    else
      button_tag(type: @type, class: class_style, onclick: on_click_event, id: @id) do
        button_label
      end
    end
  end

  def link?
    @href && !@href.empty?
  end

  def load_animation?
    @state == "animate"
  end

end
