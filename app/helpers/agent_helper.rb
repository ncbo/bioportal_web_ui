module AgentHelper

  def agent_id_alert_container_id(agent_id, parent_id)
    "agents_alerts_#{agent_id_frame_id(agent_id, parent_id)}"
  end

  def agent_alert_container_id(agent, parent_id)
    agent_id_alert_container_id(agent_id(agent), parent_id)
  end

  def agent_alert_container(agent, parent_id)
    render_alerts_container(agent_alert_container_id(agent, parent_id))
  end

  def agent_id_alert_container(agent_id, parent_id)
    render_alerts_container(agent_alert_container_id(agent, parent_id))
  end

  def agent_table_line_id(id)
    "#{id}_agent_table_item"
  end

  def agent_frame_id(agent, parent_id)
    agent_id_frame_id(agent_id(agent), parent_id)
  end

  def agent_id_frame_id(agent_id, parent_id)
    return 'application_modal_content' if parent_id.nil?

    return agent_id if parent_id.empty?

    "#{parent_id}_#{agent_id}"
  end

  def agent_id(agent)
    return  if agent.nil?

    agent_id = agent.is_a?(String) ? agent : agent.id
    agent_id ? agent_id.split('/').last : ''
  end

  def link_to_agent_edit_modal(agent, parent_id = nil)

    link_to_modal(nil, edit_agent_path(agent_id(agent), parent_id: parent_id, show_affiliations: parent_id.nil? || parent_id.empty?), class: 'btn btn-sm btn-light', data: { show_modal_title_value: "#{t('agents.edit_agent')} #{agent.name}" }) do
      content_tag(:i, '', class: 'far fa-edit')
    end
  end

  def link_to_agent_edit(agent, parent_id, name_prefix, deletable: false, show_affiliations: true)
    link_to(edit_agent_path(agent_id(agent), name_prefix: name_prefix, deletable: deletable, parent_id: parent_id, show_affiliations: show_affiliations), class: 'btn btn-sm btn-light agent-edit-icon') do
      content_tag(:i, '', class: 'far fa-edit')
    end
  end


  def link_to_search_agent(id, parent_id , name_prefix, agent_type, editable, deletable)
    link_to("/agents/show_search?id=#{id}&parent_id=#{parent_id}&agent_type=#{agent_type}&editable=#{editable}&deletable=#{deletable}&name_prefix=#{name_prefix}", class: 'btn btn-sm btn-light') do
      inline_svg_tag "x.svg", width: "25", height: "25"
    end
  end

  def agent_search_input(id, agent_type, parent_id: , name_prefix:, editable: true, deletable: false)
    render TurboFrameComponent.new(id: agent_id_frame_id(id, parent_id)) do
      render AgentSearchInputComponent.new(id: id, agent_type: agent_type,
                                           name_prefix: name_prefix,
                                           parent_id: parent_id, deletable: deletable,
                                           editable: editable, edit_on_modal: false)
    end
  end


  def is_organization?(agent)
    agent.agentType.eql?('organization')
  end

  def identifier_link(link, link_to: true)
    if link_to
      link_to(link, link, target: '_blank')
    else
      link
    end

  end


  def agent_identifier_input(index, name_prefix, value = '', is_organization: true, input_data: nil)

    content_tag :div, id: index, class: 'd-flex' do
      content_tag(:div, class: 'w-100') do

        concat hidden_field_tag(agent_identifier_name(index , :creator, name_prefix), session[:user].id)
        if is_organization
          concat inline_svg_tag 'icons/ror.svg', class: 'agent-input-icon'
        else
          concat inline_svg_tag('orcid.svg', class: 'agent-input-icon')
        end
        notation_options = { class: 'agent-input-with-icon' }
        notation_options[:data] = input_data if input_data
        concat text_field_tag(agent_identifier_name(index, :notation, name_prefix), value, notation_options)
      end
    end
  end


  def display_identifiers(identifiers, link: true, icon: true)
    schemes_urls = { 
      ORCID: 'https://orcid.org/', 
      ISNI: 'https://isni.org/', 
      ROR: 'https://ror.org/', 
      GRID: 'https://www.grid.ac/' 
    }
    
    schemes_icons = {
      ORCID: 'orcid.svg',
      ROR: 'ror.svg',
    }
    
    Array(identifiers).map do |i|
      if i["schemaAgency"]
        schema_agency, notation = [i["schemaAgency"], i["notation"]]
      else
        schema_agency, notation = (i["id"] || i["@id"])&.split('Identifiers/')&.last&.delete(' ')&.split(':') || [nil, nil]
      end
      
      value = "#{schemes_urls[schema_agency.to_sym]}#{notation}"
      icon_path = schemes_icons[schema_agency.to_sym]
      
      if icon && icon_path
        content = inline_svg_tag("icons/#{icon_path}", class: 'identifier-icon')
      else
        content = notation
      end

      if link
        link_to(value, target: '_blank', rel: 'noopener noreferrer', title: "#{schema_agency}: #{notation}") do
          content
        end
      else
        content_tag(:span, title: "#{schema_agency}: #{notation}") do
          content
        end
      end
    end.join(' ').html_safe
  end
  
  def render_agent_partial(partial, agent)
    render_to_string(partial: partial, locals: { agent: agent })
  end

  def agents_rest_url(page = 1, pagesize = 10, display = nil)
    rest_url + agents_path + "?page=#{page}&pagesize=#{pagesize}" + (display ? "&display=#{display}" : '')
  end
  
  def agent_field_name(name, name_prefix = '')
    name_prefix&.empty? ? name : "#{name_prefix}[#{name}]"
  end

  def agent_identifier_name(index, name, name_prefix)
    agent_field_name("[identifiers][#{index}][#{name}]", name_prefix)
  end

  def new_affiliation_obj
    a = LinkedData::Client::Models::Agent.new
    a.agentType = 'organization'
    a.creator = session[:user].id
    a
  end

  def agent_usages(agent = @agent)
    usages = agent.usages.to_h
    usages.delete(:links)
    usages.delete(:context)
    usages
  end

  def agent_usages_count(agent = @agent)
    usages = agent_usages(agent)
    usages.values.flatten.size
  end

  def agents_metadata
    submission_metadata.select { |x| x["enforce"]&.include?('Agent') }.map do |x|
      SubmissionInputsHelper::SubmissionMetadataInput.new(attribute_key: x["attribute"], attr_metadata: x)
    end
  end
  def agents_metadata_attributes
    agents_metadata.map { |x| [x.attr, x.label] }
  end

  def agents_used_properties(agent)
    usages = agent_usages(agent)
    attributes = agents_metadata_attributes

    attributes.map do |attr, label|
      [attr, usages.select { |x, v| v.any? { |uri| uri[attr] } }.keys.map { |x| x.to_s.split('/')[-3] }]
    end.to_h
  end

  def agent_usage_errors_display(errors)
    content_tag(:div) do
      errors.map do |ont, message|
        content_tag(:p) do
          (content_tag(:strong, ont) + t('agents.ontology_not_valid') + agent_usage_error_display(message[:error])).html_safe
        end
      end.join.html_safe
    end
  end

  def agent_usage_error_display(error)
    error.map do |attr, details|
      details.values.join(', ').html_safe
    end.join('. ').html_safe
  end

  def display_agent(agent, link: true, target: '_blank')
    agent_chip_component(agent, target)
  end

  def agent_tooltip(agent)
    if agent.usages.nil? || agent.usages.empty?
      name = agent.name
      email = agent.email unless agent.class.eql?(LinkedData::Client::Models::Agent)
      type = agent.agentType
      identifiers = display_identifiers(agent.identifiers, link: false, icon: false)
      if agent.affiliations && agent.affiliations != []
        affiliations = ""
        agent.affiliations.each do |affiliation|
          affiliations = "#{affiliations} #{affiliation.acronym || affiliation.name}"
        end
      end
      person_icon = inline_svg_tag 'icons/person.svg' , class: 'agent-type-icon'
      organization_icon = inline_svg_tag 'icons/organization.svg', class: 'agent-type-icon'
      ror_icon = inline_svg_tag 'icons/ror.svg', class: 'agent-dependency-icon ror'
      orcid_icon = inline_svg_tag 'icons/orcid.svg', class: 'agent-dependency-icon'
      agent_icon = type == "organization" ? organization_icon : person_icon
      identifiers_icon = type == "organization" ? ror_icon : orcid_icon
      tooltip_html = generate_agent_tooltip(agent_icon, name, email, identifiers, affiliations, identifiers_icon)
      return tooltip_html
    else
      render FieldContainerComponent.new(label: t("agents.profile.collaborated_on")) do
        horizontal_list_container(agent.usages) do |sub|
          acronym = sub.to_s.sub(/\/submissions\/\d+$/, "").split(/[\/\s]/).last
          render ChipButtonComponent.new(text: acronym, type: "clickable")
        end 
      end
    end
  end

  def generate_agent_tooltip(agent_icon, name, email = nil, identifiers = nil, affiliations = nil, identifiers_icon = nil)
    content_tag(:div, class: 'agent-container') do
      content_tag(:div, agent_icon, class: 'agent-circle') +
      content_tag(:div) do
        content_tag(:div, name, class: 'agent-name') +
        content_tag(:div, email || '', class: 'agent-dependency') +
        unless identifiers.to_s.empty?
          content_tag(:div, class: 'agent-dependency') do
            identifiers_icon +
            identifiers || ''
          end
        end +
        unless affiliations.to_s.empty?
          content_tag(:div, class: 'agent-dependency') do
            inline_svg_tag('icons/organization.svg', class: 'agent-dependency-icon') +
            affiliations || ''
          end
        end
      end
    end
  end


  def agent_chip_component(agent, target = '_blank')
    person_icon = inline_svg_tag 'icons/person.svg' , class: 'agent-type-icon'
    organization_icon = inline_svg_tag 'icons/organization.svg', class: 'agent-type-icon'
    agent_icon =  person_icon

    if agent.is_a?(String)
      name = agent
      title = nil
    else
      name = agent.agentType.eql?("organization") ? (agent.acronym.presence || agent.name) : agent.name
      agent_icon = agent.agentType.eql?("organization") ? organization_icon : person_icon
      title = agent_tooltip(agent)
    end
    agent_page_url = agent.id.include?('/Agents/') ? agents_path + "/#{agent.id.split('/').last}" : nil
    render_chip_component(title, agent_icon, name, agent_page_url, target)
  end


  def render_chip_component(title, agent_icon, name, url, target= '_blank')
    chip_content = content_tag(:div, class: 'agent-chip') do
      content_tag(:div, agent_icon, class: 'agent-chip-circle') +
      content_tag(:div, name, class: 'agent-chip-name text-truncate')
    end
  
    chip = render ChipButtonComponent.new(
      type: "static",
      'data-controller': 'tooltip',
      title: title,
      style: 'max-width: 280px; display:block; line-height: unset'
    ) do
      chip_content
    end

    chip_is_clickable = url.present? && agents_enabled?
    chip_is_clickable ? link_to(chip, url, class: 'text-decoration-none', target: target, rel: 'noopener noreferrer') : chip
  end

  def orcid_number(orcid)
    return orcid.split("/").last
  end

  def agents_homepage_link(style: '', ontology: nil)
    custom_style = "font-size: 50px; line-height: 0.5; margin-left: 6px; margin-bottom: 6px; vertical-align: top; #{style}".strip
    ontology = ontology || 'all'
    link, target = api_button_link_and_target(agents_rest_url)
    render IconWithTooltipComponent.new(icon: 'json.svg',link: link, target: target, title: t('home.go_to_api'), size:'small', style: custom_style)  
  end

  def agents_create_button
    link_to_modal(
      nil,
      new_agent_path,
      id: "new_agent_btn",
      role: "button",
      data: {
        show_modal_title_value: t("agents.index.create_new_agent"),
        show_modal_size_value: "modal-xl"
      }
    ) do
      regular_button(
        "new_agent_btn",
        t("agents.index.create_new_agent"),
        variant: "secondary",
        state: "regular",
        size: nil
      ) do |btn|
        btn.icon_left do
          inline_svg_tag "icons/plus.svg"
        end
      end
    end
  end
  def agents_edit_button
    link_to_modal(
      nil,
      edit_agent_path,
      id: "edit_agent_btn",
      role: "button",
      data: {
        show_modal_title_value: t('agents.edit_agent'),
        show_modal_size_value: "modal-xl"
      }
    ) do
      render PillButtonComponent.new(text: "#{inline_svg_tag 'edit.svg'} #{t('agents.edit_agent')}".html_safe) 
    end
  end
  def ontologies_browse_path
   "/ontologies"
  end
end
