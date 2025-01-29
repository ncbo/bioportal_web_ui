# frozen_string_literal: true

class LoaderComponent < ViewComponent::Base
  include ApplicationHelper
  include ActionView::Helpers::TagHelper

  def initialize(small: false, type: nil)
    super
    @small = small
    @type = type
  end

  def small_class
    @small ? 'spinner-border-sm' : ''
  end

  def type
    !@type.eql?('pulsing')
  end

  def call
    if type
      content_tag(:div, class: 'd-flex align-items-center flex-column') do
        content_tag(:div, '', class: "spinner-border #{small_class}")
      end
    else
      content_tag(:div, class: 'loader-component') do
        content_tag(:div, class: "lds-ellipsis loader-component") do
          4.times.map{content_tag(:div)}.join.html_safe
        end
      end
    end
  end
end
