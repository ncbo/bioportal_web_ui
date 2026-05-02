# frozen_string_literal: true
require 'iso-639'

class LanguageFieldComponent < ViewComponent::Base

  include FlagIconsRails::Rails::ViewHelpers, MultiLanguagesHelper

  def initialize(value:, label: nil, auto_label: false, icon: nil)
    super()
    @value = value
    @lang_code = nil
    @label = label
    @icon = icon
    @lang_code, label = find_language_code_name(value)
    @label ||= label if auto_label
    @lang_code = @lang_code.split('-').last if @lang_code
  end

  def lang_code
    case @lang_code
    when 'en'
      @lang_code = 'gb'
    when 'ar'
      @lang_code = 'sa'
    when 'hi'
      @lang_code = 'in'
    when 'ur'
      @lang_code =  'pk'
    when 'zh'
      @lang_code =  'cn'
    when 'ja'
      @lang_code = 'jp'
    end
    @lang_code
  end

  def value
    @value&.is_a?(String) ? @value.to_s.split('/').last : 'NO-LANG'
  end
end
