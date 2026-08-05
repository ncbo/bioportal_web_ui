module ComponentsHelper
  include TermsReuses

  def tree_component(root, selected, target_frame:, sub_tree: false, id: nil, auto_click: false, submission: nil, &child_data_generator)
    root.children.sort! { |a, b| (a.prefLabel || a.id).downcase <=> (b.prefLabel || b.id).downcase }

    render TreeViewComponent.new(id: id, sub_tree: sub_tree, auto_click: auto_click) do |tree_child|
      root.children.each do |child|
        children_link, data, href = child_data_generator.call(child)

        if children_link.nil? || data.nil? || href.nil?
          raise ArgumentError, t('components.error_block')
        end

        tree_child.with_child(child: child, href: href,
                         children_href: children_link, selected: child.id.eql?(selected&.id),
                         muted: child.isInActiveScheme&.empty?,
                         target_frame: target_frame,
                         data: data, is_reused: concept_reused?(submission: submission, concept_id: child.id)) do
          tree_component(child, selected, target_frame: target_frame, sub_tree: true,
                         id: id, auto_click: auto_click, submission: submission, &child_data_generator)
        end
      end
    end
  end

  def ajax_link_chip(id, label = nil, link = nil, external: false, open_in_modal: false, ajax_src: nil, target: '_blank')
    render LabelFetcherComponent.new(id: id, label: label, link: link, open_in_modal: open_in_modal, ajax_src: ajax_src, target: target, external: external)
  end

  def tab_item_component(container_tabs:, title:, path:, id: nil, selected: false, json_link: "", &content)
    container_tabs.with_item(id: id, title: title.html_safe, path: path, selected: selected, json_link: json_link)
    container_tabs.with_item_content { capture(&content) }
  end

  def alert_component(message, type: "info")
    render Display::AlertComponent.new(type: type, message: message)
  end

  def list_items_component(max_items:, &block)
    render ListItemsShowMoreComponent.new(max_items: max_items) do |r|
      capture(r, &block)
    end
  end

  def link_to_with_actions(link_to_tag, acronym: nil, url: nil, copy: true, check_resolvability: true, generate_link: true, generate_htaccess: false)
    tag = link_to_tag
    url = link_to_tag if url.nil?

    tag += content_tag(:span, class: 'mx-1') do
      concat copy_link_to_clipboard(url) if copy
    end

    tag.html_safe
  end

  def rounded_button_component(link)
    render RoundedButtonComponent.new(link: link, target: '_blank', size: 'small', title: t("components.go_to_api"))
  end

  def copy_link_to_clipboard(url, show_content: false)
    content_tag(:span, style: 'display: inline-block;') do
      render ClipboardComponent.new(title: t("components.copy_original_uri"), message: url, show_content: show_content)
    end
  end

  # The short, community-facing "OBO-style" id for a class — e.g. "GO:0008150"
  # for the IRI http://purl.obolibrary.org/obo/GO_0008150. Biomedical users refer
  # to classes by this CURIE far more than by the full IRI.
  #
  # Prefer an explicit id/notation annotation on the class (the authoritative
  # value); otherwise derive PREFIX:LOCAL from the IRI's last segment when it
  # looks like an OBO/CURIE-style local name (PREFIX_LOCAL). Returns nil when the
  # class has no such id, so callers can skip the pill entirely.
  def obo_style_id(concept)
    return nil if concept.nil?

    annotated = obo_id_from_annotations(concept)
    return annotated if annotated.present?

    obo_id_from_iri(concept.id)
  end

  # Look for an id/notation annotation (e.g. oboInOwl#id, skos:notation) whose
  # value is a CURIE like "GO:0008150".
  def obo_id_from_annotations(concept)
    props = concept.respond_to?(:properties) ? concept.properties : nil
    return nil if props.nil? || !props.respond_to?(:members)

    props.members.each do |key|
      key_s = key.to_s
      next unless key_s =~ %r{[#/](id|notation)\z}i

      Array(props[key]).each do |value|
        str = value.respond_to?(:object) ? value.object : value
        str = str.to_s.strip
        return str if str =~ /\A[A-Za-z][\w.-]*:\S+\z/
      end
    end
    nil
  end

  # Derive PREFIX:LOCAL from the last IRI segment when it matches PREFIX_LOCAL
  # (e.g. .../GO_0008150 -> GO:0008150). Only the first underscore is treated as
  # the prefix separator, so local names containing underscores are preserved.
  def obo_id_from_iri(iri)
    return nil if iri.blank?

    last = iri.to_s.include?('#') ? iri.to_s.split('#').last : iri.to_s.split('/').last
    return nil if last.blank?

    m = last.match(/\A([A-Za-z][A-Za-z0-9]*)_(.+)\z/)
    return nil unless m

    "#{m[1]}:#{m[2]}"
  end

  def loader_component(type: 'pulsing', small: false)
    render LoaderComponent.new(type: type, small: small)
  end

  def info_tooltip(text, interactive: true)
    render Display::InfoTooltipComponent.new(text: text, interactive: interactive)
  end

  def empty_state_message(message)
    content_tag(:p, message.html_safe, class: 'font-italic field-description_text')
  end

  def regular_button(id, value, variant: "secondary", state: "regular", size: "slim", &block)
    render Buttons::RegularButtonComponent.new(id: id, value: value, variant: variant, state: state, size: size) do |btn|
      capture(btn, &block) if block_given?
    end
  end

  def chips_component(id:, name:, label:, value:, checked: false, tooltip: nil, disabled: false, &block)
    content_tag(:div, data: { controller: 'tooltip' }, title: tooltip) do
      check_input(id: id, name: name, value: value, label: label, checked: checked, disabled: disabled, &block)
    end
  end

  def group_chip_component(id: nil, name:, object:, checked:, value: nil, title: nil, disabled: false, &block)
    title ||= object["name"]
    value ||= (object["value"] || object["acronym"] || object["id"])

    chips_component(id: id || value, name: name, label: object["acronym"],
                    checked: checked,
                    value: value, tooltip: title, disabled: disabled, &block)
  end

  def form_save_button(enable_loading: true)
    render Buttons::RegularButtonComponent.new(id: 'save-button', value: t('components.save_button'), variant: "primary", size: "slim", type: "submit", state: enable_loading ? 'animate' : '') do |btn|
      btn.icon_left do
        inline_svg_tag "check.svg"
      end
    end
  end

  def form_cancel_button
    render Buttons::RegularButtonComponent.new(id: 'cancel-button', value: t('components.cancel_button'), variant: "secondary", size: "slim") do |btn|
      btn.icon_left do
        inline_svg_tag "x.svg", width: "9", height: "9"
      end
    end
  end

end
