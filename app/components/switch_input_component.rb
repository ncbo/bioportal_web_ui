# frozen_string_literal: true

class SwitchInputComponent < ViewComponent::Base


  def initialize(id:, name: , label: '', value: '', checked: false, boolean_switch: false, style: nil, help: nil)
    super()
    @id = id
    @name = name
    @label = label
    @value = value.nil? || value.empty? ? @name : value
    @checked = checked
    @boolean_switch = boolean_switch
    @style = style
    @help = help
  end

  def boolean_switch_action
    "this.parentElement.previousElementSibling.value = this.parentElement.previousElementSibling.value !== 'true'" if @boolean_switch
  end

  def check_box_name
    @name unless @boolean_switch
  end

  def check_box_id
    @boolean_switch ? @id +"_checkbox" :@id
  end
end
