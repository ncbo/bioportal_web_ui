# frozen_string_literal: true

class LinkFieldComponent < ViewComponent::Base

  include ApplicationHelper, Turbo::FramesHelper, ComponentsHelper

  def initialize(value:, acronym: nil, raw: false, check_resolvability: false, enable_copy: true,  generate_link: false, generate_htaccess: false)
    super()
    @value = value
    @raw = raw
    @check_resolvability = check_resolvability
    @enable_copy = enable_copy
    @acronym = acronym
    @generate_link = generate_link
    @generate_htaccess = generate_htaccess
  end

  def internal_link?
    @value.to_s.include?(URI.parse($REST_URL).hostname) || @value.to_s.include?(URI.parse($UI_URL).hostname)
  end

  def link_tag
    if !@raw && internal_link?
      url = @value.to_s.split("/").last
      text = @value.to_s.sub("data.", "")
      target = ""
    else
      url = @value.to_s
      text = url
      target = "_blank"
    end

    tag = link_to(text, url, target: target, class: 'summary-link-truncate', 'data-controller': 'tooltip', title: text)
    link_to_with_actions(tag, acronym: @acronym, url: url, copy: @enable_copy, check_resolvability: @check_resolvability, generate_link: @generate_link, generate_htaccess: @generate_htaccess)
  end

end
