module SubmissionInputsHelper
  class SubmissionMetadataInput
    include MetadataHelper, ApplicationHelper

    def initialize(attribute_key:, attr_metadata:, submission: nil, label: nil)
      @attribute_key = attribute_key
      @attr_metadata = attr_metadata
      @submission = submission
      @label = label
    end

    def attr
      @attribute_key
    end

    alias :attr_key :attr

    def attr_key
      @attribute_key
    end

    def name
      "submission[#{@attribute_key}]"
    end

    def values
      @submission.send(@attr_metadata['attribute'])
    rescue StandardError
      nil
    end

    def help_text
      CGI.unescape_html(@attr_metadata['helpText']) if @attr_metadata['helpText']
    end

    def label
      return attr_key unless @attr_metadata

      @label || @attr_metadata['label'] || @attr_metadata['attribute'].humanize
    end

    def type?(type)
      @attr_metadata['enforce'].include?(type)
    end

    def metadata
      @attr_metadata
    end

    def required?
      Array(@attr_metadata['enforce']).include?('existence')
    end
  end

  # @param attr_key String
  def attribute_input(attr_key, long_text: false, label: nil, show_tooltip: true, max_date: nil, help: nil)
    attr = SubmissionMetadataInput.new(attribute_key: attr_key, submission: @submission, label: label,
                                       attr_metadata: attr_metadata(attr_key))

    if attr.type?('integer')
      generate_integer_input(attr)
    elsif attr.type?('date_time')
      if attr.type?('list')
        generate_list_date_input(attr, max_date: max_date)
      else
        generate_date_input(attr, max_date: max_date)
      end
    elsif attr.type?('textarea')
      generate_textarea_input(attr)
    elsif enforce_values?(attr)

      if attr.type?('list')
        generate_select_input(attr, multiple: true, help_text: help)
      elsif attr.type?('boolean')
        generate_boolean_input(attr, help: help)
      else
        generate_select_input(attr, help_text: help)
      end
    elsif attr.type?('isOntology')
      generate_select_input(attr, multiple: attr['enforce'].include?('list'))
    elsif attr.type?('uri')
      generate_url_input(attr, helper_text: help)
    elsif attr.type?('boolean')
      generate_boolean_input(attr, help: help)
    else
      # If input a simple text
      name = attr.name
      label = attr_header_label(attr, show_tooltip: show_tooltip)
      if attr.type?('list')
        generate_list_text_input(attr, helper_text: help, long_text: long_text)
      elsif attr.metadata['attribute'].to_s.eql?('uri')
        url_input(name: name, label: label, value: @submission.uri)
      elsif long_text
        text_area_input(name: name, label: label,
                        value: attr.values, resize: true)
      else
        text_input(name: name, label: label,
                   value: attr.values, help: help)
      end
    end

  end

  def ontology_name_input(ontology = @ontology, label: 'Name')
    content_tag(:div, class: 'mb-2') do
      text_input(name: 'ontology[name]', value: ontology.name, label: label_required(label))
    end
  end

  def ontology_acronym_input(ontology = @ontology, update: @is_update_ontology, label: 'Acronym')
    out = text_input(name: 'ontology[acronym]', value: ontology.acronym, disabled: update, label: label_required(label))
    out += hidden_field_tag('ontology[acronym]', ontology.acronym) if update
    content_tag(:div, out, class: 'my-1')
  end

  def ontology_administered_by_input(ontology = @ontology, users_list = @user_select_list)
    unless users_list
      users_list = LinkedData::Client::Models::User.all(include: "username").map { |u| [u.username, u.id] }
      users_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    end
    select_input(label: label_required(t('submission_inputs.administrators')), name: "ontology[administeredBy]", values: users_list, selected: ontology.administeredBy || session[:user].id, multiple: true)
  end

  def ontology_categories_input(ontology = @ontology, categories = @categories)
    categories ||= LinkedData::Client::Models::Category.all(display_links: false, display_context: false)
    sorted_categories = categories.sort_by! { |c| c[:name].to_s.downcase }

    render Input::InputFieldComponent.new(name: '', label: 'Categories') do
      content_tag(:div, class: 'upload-ontology-chips-container') do
        hidden_field_tag('ontology[hasDomain][]') +
          sorted_categories.map do |category|
            content_tag(:div) do
              category_chip_component(id: category[:acronym], name: "ontology[hasDomain][]",
                                      object: category, value: category[:id],
                                      checked: ontology.hasDomain&.any? { |x| x.eql?(category[:id]) })
            end
          end.join.html_safe
      end
    end
  end

  def ontology_skos_language_help
    content_tag(:div, class: 'upload-ontology-desc has_ontology_language_input') do
      link = link_to(t('submission_inputs.ontology_skos_language_link'), "https://doc.jonquetlab.lirmm.fr/share/618372fb-a852-4f3e-8e9f-8b07ebc053e6", target: "_blank")
      text = t('submission_inputs.ontology_skos_language_help', portal_name: portal_name, link: link)
      text.html_safe
    end
  end

  def ontology_obo_language_help
    content_tag(:div, class: 'upload-ontology-desc has_ontology_language_input') do
      link = link_to(t('submission_inputs.ontology_obo_language_link'), "#", target: "_blank")
      text = t('submission_inputs.ontology_obo_language_help', portal_name: portal_name, link: link)
      text.html_safe
    end
  end

  def ontology_owl_language_help
    content_tag(:div, class: 'upload-ontology-desc has_ontology_language_input') do
      link = link_to(t('submission_inputs.ontology_owl_language_link'), "https://protege.stanford.edu/", target: "_blank")
      text = t('submission_inputs.ontology_owl_language_help', portal_name: portal_name, link: link)
      text.html_safe
    end
  end

  def ontology_umls_language_help
    content_tag(:div, class: 'upload-ontology-desc has_ontology_language_input') do
      link = link_to(t('submission_inputs.ontology_umls_language_link'), "#", target: "_blank")
      text = t('submission_inputs.ontology_umls_language_help', link: link)
      text.html_safe
    end
  end

  def has_ontology_language_input(submission = @submission)
    render(Layout::RevealComponent.new(possible_values: %w[SKOS OBO UMLS OWL], selected: submission.hasOntologyLanguage)) do |c|
      c.with_button do
        attribute_input("hasOntologyLanguage")
      end

      c.with_container { ontology_skos_language_help }

      c.with_container { ontology_obo_language_help }

      c.with_container { ontology_umls_language_help }

      c.with_container { ontology_owl_language_help }

    end
  end

  def ontology_groups_input(ontology = @ontology, groups = @groups)
    groups ||= LinkedData::Client::Models::Group.all(display_links: false, display_context: false)
    sorted_groups = groups.sort_by { |g| g[:name] }

    render Input::InputFieldComponent.new(name: '', label: t('submission_inputs.groups')) do
      content_tag(:div, class: 'upload-ontology-chips-container') do
        hidden_field_tag('ontology[group][]') +
          sorted_groups.map do |group|
            group_chip_component(name: "ontology[group][]", id: group[:acronym],
                                 object: group, value: group[:id],
                                 checked: ontology.group&.any? { |x| x.eql?(group[:id]) })
          end.join.html_safe
      end
    end
  end

  def ontology_visibility_input(ontology = @ontology)
    unless @user_select_list
      @user_select_list = LinkedData::Client::Models::User.all(include: "username").map { |u| [u.username, u.id] }
      @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    end

    render(Layout::RevealComponent.new(possible_values: %w[private public], selected: ontology.viewingRestriction)) do |c|
      c.with_button do
        select_input(label: label_required(t('submission_inputs.visibility')), name: "ontology[viewingRestriction]", required: true,
                     values: %w[public private],
                     selected: ontology.viewingRestriction)
      end

      c.with_container do
        content_tag(:div, class: 'upload-ontology-input-field-container') do
          select_input(label: t('submission_inputs.accounts_allowed', portal_name: portal_name), name: "ontology[acl]", values: @user_select_list, selected: ontology.acl, multiple: true)
        end
      end
    end
  end


  def onts_for_select(include_views: false)
    ontologies ||= LinkedData::Client::Models::Ontology.all({include: "acronym,name,viewOf", include_views: include_views})
    onts_for_select = [['', '']]
    ontologies.each do |ont|
      next if ( ont.acronym.nil? or ont.acronym.empty? )
      acronym = ont.acronym
      name = ont.name
      abbreviation = acronym.empty? ? "" : "(#{acronym})"
      ont_label = "#{name.strip} #{abbreviation}#{ont.viewOf ? ' [view]' : ''}"
      onts_for_select << [ont_label, acronym]
    end
    onts_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    onts_for_select
  end

  def ontology_view_of_input(ontology = @ontology)
    render Layout::RevealComponent.new(selected: ontology.view?, toggle: true) do |c|
      c.with_button do
        content_tag(:span, class: 'd-flex') do
          switch_input(id: 'ontology_isView', name: 'ontology[isView]', label: t('submission_inputs.ontology_view_of_another_ontology'), checked: ontology.view?, style: 'font-size: 14px;')
        end
      end
      c.with_container do
        content_tag(:div) do
          render SelectInputComponent.new(id: 'viewOfSelect', values: onts_for_select, name: 'ontology[viewOf]', selected: ontology.viewOf&.split('/')&.last)
        end
      end
    end
  end

  def contact_input(label: '', name: t('submission_inputs.contact'), show_help: true)
    attr = SubmissionMetadataInput.new(attribute_key: 'contact', attr_metadata: attr_metadata('contact'))
    render Input::InputFieldComponent.new(name: '', label: attr_header_label(attr, label, show_tooltip: show_help),
                                          error_message: attribute_error(:contact)) do

      render NestedFormInputsComponent.new(object_name: 'contact', default_empty_row: true) do |c|
        c.with_header do
          content_tag(:div, name.blank? ? '' : label_required(t('submission_inputs.contact_name', name: name)), class: 'w-50') + content_tag(:div, name.blank? ? '' : label_required(t('submission_inputs.contact_email', name: name)), class: 'w-50')
        end

        c.with_template do
          content_tag(:div, class: 'd-flex my-1') do
            out = content_tag(:div, class: ' w-50 me-2') do
              text_input(label: '', name: 'submission[contact][NEW_RECORD][name]', value: '', error_message: '')
            end
            out + content_tag(:div, class: ' w-50') do
              text_input(label: '', name: 'submission[contact][NEW_RECORD][email]', value: '', error_message: '')
            end
          end
        end

        Array(@submission.contact).each_with_index do |contact, i|
          c.with_row do
            content_tag(:div, class: 'd-flex my-1') do
              out = content_tag(:div, class: 'w-50 me-2') do
                text_input(label: '', name: "submission[contact][#{i}][name]", value: contact['name'], error_message: '')
              end
              out + content_tag(:div, class: 'w-50') do
                text_input(label: '', name: "submission[contact][#{i}][email]", value: contact['email'], error_message: '')
              end
            end
          end
        end
      end
    end
  end

  # @param attr_key string
  def attr_label(attr_key, label = nil, attr_metadata: attr_metadata(attr_key), show_tooltip: true)

    data = SubmissionMetadataInput.new(attribute_key: attr_key.to_s, attr_metadata: attr_metadata)
    if show_tooltip
      attr_header_label(data, label, show_tooltip: show_tooltip)
    else
      label || data.label
    end
  end

  private

  def agent_type(attr)
    if input_type?(attr, 'is_person')
      'person'
    elsif input_type?(attr, 'is_organization')
      'organization'
    else
      ''
    end
  end

  def generate_integer_input(attr)
    # TODO to update to use a component
    number_field object_name, attr.metadata['attribute'].to_s.to_sym, value: @submission.send(attr.metadata['attribute']), class: 'metadataInput form-control'
  end

  def generate_agent_input(attr)
    attr_key = attr.metadata['attribute'].to_s
    agent = attr.values
    random_id = rand(100_000..999_999).to_s
    render Input::InputFieldComponent.new(name: '', label: attr_header_label(attr), error_message: attribute_error(attr.metadata['attribute'])) do
      render TurboFrameComponent.new(id: "submission_#{attr_key}_#{random_id}") do
        if agent
          render partial: 'agents/agent_show', locals: { agent_id: random_id,
                                                         agent: agent,
                                                         name_prefix: attr.name,
                                                         parent_id: "submission_#{attr_key}",
                                                         edit_on_modal: false, deletable: true }
        else
          render AgentSearchInputComponent.new(id: random_id, agent_type: agent_type(attr.metadata),
                                               parent_id: "submission_#{attr_key}",
                                               edit_on_modal: false,
                                               name_prefix: attr.name,
                                               deletable: true)
        end
      end
    end
  end

  def generate_list_agent_input(attr, helper_text: nil)
    render Input::InputFieldComponent.new(name: '', error_message: attribute_error(attr.metadata['attribute']), helper_text: helper_text) do
      render NestedAgentSearchInputComponent.new(label: attr_header_label(attr),
                                                 agents: attr.values,
                                                 agent_type: agent_type(attr.metadata),
                                                 name_prefix: attr.name,
                                                 parent_id: attr.attr)
    end

  end

  def generate_list_date_input(attr, max_date: nil)
    generate_list_field_input(attr, attr.name, attr_header_label(attr), attr.values) do |value, row_name, id|
      date_input(label: '', name: row_name,
                 value: value,
                 max_date: max_date)
    end

  end

  def generate_date_input(attr, max_date: nil)
    date_input(label: attr_header_label(attr), name: attr.name,
               value: (Date.parse(attr.values).to_s rescue attr.values),
               max_date: max_date)
  end

  def generate_textarea_input(attr)
    text_input(name: attr.name,
               value: attr.values, helper_text: nil)
  end

  def generate_select_input(attr, multiple: false, help_text: nil)
    name = attr.name
    label = attr_header_label(attr)
    metadata_values, select_values = selected_values(attr, enforced_values(attr))

    if !multiple && !attr.required?
      select_values << ['', '']
      metadata_values = '' if metadata_values.nil?
    end

    select_input(name: name, label: label, values: select_values,
                 selected: metadata_values, multiple: multiple, required: attr.required?,
                 open_to_add: open_to_add_metadata?(attr.attr_key), help: help_text)
  end

  def generate_list_field_input(attr, name, label, values, helper_text: nil, &block)
    render Input::InputFieldComponent.new(name: '', error_message: attribute_error(attr.attr), helper_text: helper_text) do
      render NestedFormInputsComponent.new do |c|
        c.with_header do
          label
        end
        c.with_template do
          block.call('', "#{name}[NEW_RECORD]", attr.attr.to_s + '_' + @ontology.acronym)
        end

        c.with_empty_state do
          hidden_field_tag "#{name}[#{Array(values).size}]"
        end

        Array(values).each_with_index do |metadata_val, i|
          c.row do
            block.call(metadata_val, "#{name}[#{i}]", "submission_#{attr.attr.to_s}" + '_' + @ontology.acronym)
          end
        end
      end
    end

  end

  def generate_url_input(attr, helper_text: nil)
    label = attr_header_label(attr)
    values = attr.values
    name = attr.name

    is_relation = ontology_relation?(attr.attr_key)
    if attr.type?('list')
      if is_relation
        generate_ontology_select_input(name, label, values, true)
      else
        generate_list_field_input(attr, name, label, values, helper_text: helper_text) do |value, row_name, id|
          url_input(label: '', name: row_name, value: value)
        end
      end
    else
      if is_relation
        generate_ontology_select_input(name, label, values, false)
      else
        url_input(label: label, name: name, value: values, help: helper_text)
      end
    end
  end

  def generate_ontology_select_input(name, label, selected, multiple, reject_ontology: @ontology)
    unless @ontology_acronyms
      @ontology_acronyms = LinkedData::Client::Models::Ontology.all(include: 'acronym,name', display_links: false, display_context: false, include_views: true)
                                                               .map { |x| ["#{x.name} (#{x.acronym})", x.id.to_s] }
      @ontology_acronyms << ['', '']
    end

    @ontology_acronyms = @ontology_acronyms.reject { |acronym, id| id == reject_ontology.id }

    input = ''

    input = hidden_field_tag("#{name}[]") if multiple

    input + select_input(id: name, name: name,
                         label: label, values: @ontology_acronyms + Array(selected),
                         selected: selected, multiple: multiple,
                         open_to_add: true)
  end

  def generate_list_text_input(attr, helper_text: nil, long_text: false)
    label = attr_header_label(attr)
    values = attr.values || ['']
    name = attr.name

    generate_list_field_input(attr, name, label, values, helper_text: helper_text) do |value, row_name, id|
      if long_text
        text_area_tag(row_name, value, class: 'input-field-component', label: '', style: 'resize: vertical;')
      else
        text_input(label: '', name: row_name, value: value)
      end
    end
  end

  def generate_boolean_input(attr, help: nil)
    value = attr.values
    value = value.to_s unless value.nil?
    name = attr.name
    content_tag(:div) do
      switch_input(id: name, name: name, label: attr_header_label(attr), checked: value.eql?('true'), value: value,
                   boolean_switch: true, style: 'font-size: 14px;', help: help)
    end
  end

  def enforce_values?(attr)
    !attr.metadata['enforcedValues'].nil?
  end

  def enforced_values(attr)
    attr.metadata['enforcedValues'].collect { |k, v| [v || k, k] }
  end

  def selected_values(attr, enforced_values)
    metadata_values = attr.values
    select_values = enforced_values

    if metadata_values.kind_of?(Array)
      metadata_values.map do |metadata|
        select_values << metadata unless select_values.flatten.include?(metadata)
      end
    elsif !select_values.flatten.include?(metadata_values) && !metadata_values.to_s.empty?
      select_values << metadata_values
    end
    [metadata_values, select_values]
  end

  def attr_header_label(attr, label = nil, show_tooltip: true)
    label ||= attr.label
    return '' if label.nil? || label.empty?

    content_tag(:div) do
      tooltip_span = render(Display::InfoTooltipComponent.new(text: attribute_help_text(attr)))
      html = content_tag(:span, label)
      html += content_tag(:span, '*', class: "text-danger") if attr.required?
      html += content_tag(:span, tooltip_span, class: 'ms-1') if show_tooltip
      html
    end
  end

  def attribute_help_text(attr)
    label = attr.label
    help = attr.help_text
    required = attr.required?
    attr = attr.metadata
    attribute = !attr['namespace'].nil? ? "#{attr['namespace']}:#{attr['attribute']}" : "bioportal:#{attr['attribute']}"

    title = content_tag(:span, "#{label} (#{attribute})")
    title += content_tag(:span, 'required', class: 'badge badge-danger mx-1') if required

    render SummarySectionComponent.new(title: title, show_card: false) do
      help_text = ''

      unless attr['helpText'].nil?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.help_text'), value: help.html_safe))
      end

      unless attr['metadataMappings'].nil?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.equivalents'), value: attr['metadataMappings'].join(', ')))
      end

      unless attr['enforce'].nil? || attr['enforce'].empty?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.validators'), value: attr['enforce'].map do |x|
          content_tag(:span, x.humanize, class: 'badge bg-primary mx-1')
        end.join.html_safe))
      end

      help_text
    end
  end

  def label_required(label)
    content_tag(:div) do
      label.html_safe +
        content_tag(:span, '*', style: 'color: var(--error-color);')
    end
  end
end
