require 'iso-639'
module OntologiesHelper
  REST_URI = $REST_URL
  API_KEY = $API_KEY
  LANGUAGE_FILTERABLE_SECTIONS = %w[classes schemes collections instances properties].freeze

  def ontology_access_denied?
    @ontology&.errors&.include?('Access denied for this resource')
  end

  def concept_search_input(placeholder)
    content_tag(:div, class: 'search-inputs p-1') do
      text_input(placeholder: placeholder, label: '', name: "search", value: '', data: { action: "input->browse-filters#dispatchInputEvent" })
    end
  end

  def tree_container_component(id:, placeholder:, frame_url:, tree_url:)
    content_tag(:div, class: 'search-page-input-container', data: { controller: "turbo-frame history browse-filters", "turbo-frame-url-value": frame_url, action: "changed->turbo-frame#updateFrame" }) do
      concat(concept_search_input(placeholder))
      concat(content_tag(:div, class: 'tree-container') do
        render(TurboFrameComponent.new(
          id: id,
          src: tree_url,
          data: { 'turbo-frame-target': 'frame' }
        ))
      end)
    end
  end

  def ontology_retired?(submission)
    submission[:status].to_s.eql?('retired') || submission[:deprecated].to_s.eql?('true')
  end
  def ontology_license_badge(acronym, submission = @submission_latest)
    return if submission.nil?

    no_license = submission.hasLicense.blank?
    render ChipButtonComponent.new(class: "text-nowrap chip_button_small #{no_license && 'disabled-link'}", type: no_license ? 'static' : 'clickable') do
      if no_license
        content_tag(:span) do
          content_tag(:span, t('ontologies.no_license'), class: "mx-1") + inline_svg_tag('icons/law.svg', width: "15px")
        end
      else
        link_to_modal(nil, "/ajax/submission/show_licenses/#{acronym}",data: { show_modal_title_value: t('ontologies.access_rights_information')}) do
          content_tag(:span, t('ontologies.view_license'), class: "mx-1") + inline_svg_tag('icons/law.svg')
        end
      end

    end
  end
  def ontology_retired_badge(submission, small: false, clickable: true)
    return if submission.nil? || !ontology_retired?(submission)
    text_color = submission[:status].to_s.eql?('retired') ? 'text-danger bg-danger-light' : 'text-warning bg-warning-light'
    text_content = submission[:status].to_s.eql?('retired') ?  'Retired' : 'Deprecated'
    style = "#{text_color} #{small && 'chip_button_small'}"
    render ChipButtonComponent.new(class:  "#{style} mr-1", text: text_content, type: clickable ? 'clickable' : 'static')
  end

  def ontology_alternative_names(submission = @submission_latest)
    alt_labels = (Array(submission&.alternative) + Array(submission&.hiddenLabel))
    return unless alt_labels.present?

    content_tag(:div, class: 'creation_text') do
      concat(t('ontologies.referred_to'))
      concat(content_tag(:span, class: 'date_creation_text') do
        if alt_labels.length > 1
          concat("#{alt_labels[0..-2].join(', ')} or #{alt_labels.last}.")
        else
          concat("#{alt_labels.first}.")
        end
      end)
    end
  end

  def private_ontology_icon(is_private)
    raw(content_tag(:i, '', class: 'fas fa-key', title: t('ontologies.private_ontology'))) if is_private
  end

  def ontologies_browse_skeleton(pagesize = 5)
    pagesize.times do
      concat render OntologyBrowseCardComponent.new
    end
  end

  def ontologies_with_filters_url(filters, page: 1, count: false, user: false)
    url = user ? "/user_ontologies_filter?" : '/ontologies_filter?'
    url += "page=#{page}" if page
    url += "count=#{page}" if count
    if filters
      filters_str = filters.reject { |k, v| v.nil? || (k.eql?(:sort_by) && count) }
                           .map { |k, v| "#{k}=#{v}" }.join('&')
      url += "&#{filters_str}"
    end
    url
  end

  def additional_details
    return "" if $ADDITIONAL_ONTOLOGY_DETAILS.nil? || $ADDITIONAL_ONTOLOGY_DETAILS[@ontology.acronym].nil?
    details = $ADDITIONAL_ONTOLOGY_DETAILS[@ontology.acronym]
    html = []
    details.each do |title, value|
      html << content_tag(:tr) do
        html << content_tag(:td, title)
        html << content_tag(:td, raw(value))
      end
    end
    html.join('')
  end

  # Display data catalog metadata under visits (in _metadata.html.haml)
  def display_data_catalog(value)
    if !value.nil? && value.any?
      # Buttons for data catalogs
      content_tag(:div, { :class => "" }) do

      end
    else
      ""
    end
  end

  def agent?(sub_metadata, attr)
    metadata = sub_metadata.select { |x| x['@id'][attr] }.first
    metadata && Array(metadata['enforce']).include?('Agent')
  end

  def display_contact(contacts)
    contacts.map do |c|
      next unless c.member?(:name) && c.member?(:email)

      formatted_name = c[:name].titleize
      formatted_email = c[:email].downcase
      "<span class='date_creation_text'>#{formatted_name}</span> (#{formatted_email})"
    end&.join(" and ")
  end

  def count_links(ont_acronym, page_name = 'summary', count = 0)
    ont_url = "/ontologies/#{ont_acronym}"
    if count.nil? || count.zero?
      return '0'
    else
      return "<a href='#{ont_url}/?p=#{page_name}'>#{number_with_delimiter(count, delimiter: ',')}</a>"
    end
  end

  def classes_link(ontology, count)
    return '0' if ontology.summaryOnly || count.nil? || count.zero?

    count_links(ontology.ontology.acronym, 'classes', count)
  end

  def metadata_filled_count(submission = @submission_latest, ontology = @ontology)
    return if submission.nil?

    reject = [:csvDump, :dataDump, :openSearchDescription, :metrics, :prefLabelProperty, :definitionProperty,
              :definitionProperty, :synonymProperty, :authorProperty, :hierarchyProperty, :obsoleteProperty,
              :ontology, :endpoint, :submissionId, :submissionStatus, :uploadFilePath, :context, :links, :ontology]
    sub_values = submission.to_hash.except(*reject).values
    count = sub_values.count{|x| !x.blank?}
    content_tag(:div, class: 'd-flex align-items-center justify-content-center') do
      content_tag(:span, style:'width: 50px; height: 50px', data: {controller: 'tooltip'}, title: "#{count} of #{sub_values.size}") do
        render CircleProgressBarComponent.new(count: count , max:  sub_values.size )
      end  +  content_tag(:span, class: 'mx-1') { t('ontologies.metadata_properties', acronym: ontology.acronym)}
    end.html_safe
  end

  # Creates a link based on the status of an ontology submission
  def download_link(submission, ontology = nil)
    ontology ||= @ontology
    links = []
    if ontology.summaryOnly
      if submission.homepage.nil?
        links << { href: '', label: t('ontologies.metadata_only') }
      else
        uri = submission.homepage
        links << { href: uri, label: t('ontologies.home_page') }
      end
    else
      uri = submission.id + "/download"
      href, target = api_button_link_and_target(uri, allow_annonymous = true)
      links << { href: href, label: submission.pretty_format, target: target }
      if submission_ready?(submission)
        uri = "#{ontology.id}/download?download_format=csv"
        href, target = api_button_link_and_target(uri, allow_annonymous = true)
        links << { href: href, label: "CSV", target: target }
        unless submission.hasOntologyLanguage.eql?('UMLS')
          uri = "#{ontology.id}/download?download_format=rdf"
          href, target = api_button_link_and_target(uri, allow_annonymous = true)
          links << { href: href, label: "RDF/XML", target: target }
        end
      end
      unless submission.diffFilePath.nil?
        uri = submission.id + "/download_diff"
        href, target = api_button_link_and_target(uri, allow_annonymous = true)
        links << { href: href, label: "DIFF", target: target }
      end
    end
    links
  end



  def mappings_link(ontology, count)
    return '0' if ontology.summaryOnly || count.nil? || count.zero?

    count_links(ontology.ontology.acronym, 'mappings', count)
  end

  def notes_link(ontology, count)
    count_links(ontology.ontology.acronym, 'notes', count)
  end

  # Creates a link based on the status of an ontology submission
  def status_link(submission, latest = false, target = '')
    version_text = submission.version.nil? || submission.version.to_s.length == 0 ? 'unknown' : submission.version.to_s
    status_text = " <span class='ontology_submission_status'>" + submission_status2string(submission) + '</span>'
    if submission.ontology.summaryOnly || latest == false
      version_link = version_text
    else
      version_link = "<a href='/ontologies/#{submission.ontology.acronym}?p=classes' #{target.empty? ? '' : "target='#{target}'"}>#{version_text}</a>"
    end
    version_link + status_text
  end


  def submission_status2string(data)
    return '' if data[:submissionStatus].nil?

    # Massage the submission status into a UI string
    # submission status values, from:
    # https://github.com/ncbo/ontologies_linked_data/blob/master/lib/ontologies_linked_data/models/submission_status.rb
    # "UPLOADED", "RDF", "RDF_LABELS", "INDEXED", "METRICS", "ANNOTATOR", "ARCHIVED"  and 'ERROR_*' for each.
    # Strip the URI prefix from the status codes (works even if they are not URIs)
    # The order of the codes must be assumed to be random, it is not an entirely
    # predictable sequence of ontology processing stages.
    codes = data[:submissionStatus].map { |s| s.split('/').last }
    errors = codes.select { |c| c.start_with? 'ERROR' }.map { |c| c.gsub("_", " ").split(/(\W)/).map(&:capitalize).join }.compact
    status = []
    status.push('Parsed') if (codes.include? 'RDF') && (codes.include? 'RDF_LABELS')
    # The order of this array imposes an oder on the UI status code string
    status_list = ['INDEXED', 'METRICS', 'ANNOTATOR', 'ARCHIVED']
    status_list.insert(0, 'UPLOADED') unless status.include?('Parsed')
    status_list.each do |c|
      status.push(c.capitalize) if codes.include? c
    end
    status.concat errors
    return '' if status.empty?

    '(' + status.join(', ') + ')'
  end

  def status_string(data)
    return '' unless data.present? && data[:submissionStatus].present?

    submission_status2string(data)
  end

  def submission_status_ok?(status)
    status.include?('Parsed') && !status.include?('Error')
  end

  def submission_status_error?(status)
    !status.include?('Parsed') && status.include?('Error')
  end

  def submission_status_warning?(status)
    status.include?('Parsed') && status.include?('Error')
  end

  def submission_status_icons(status)
    if submission_status_ok?(status)
      status_icons(ok: true)
    elsif submission_status_error?(status)
      status_icons(error: true)
    elsif status == '(Archived)'
      'archive.svg'
    elsif submission_status_warning?(status)
      status_icons(warning: true)
    else
      "info.svg"
    end
  end

  def status_icons(ok: false, error: false, warning: false)
    if ok
      "success-icon.svg"
    elsif error
      'error-icon.svg'
    elsif warning
      "alert-triangle.svg"
    else
      "info.svg"
    end
  end

  # Link for private/public/licensed ontologies
  def visibility_link(ontology)
    ont_url = "/ontologies/#{ontology.acronym}" # 'ontology' is NOT a submission here
    page_name = 'summary' # default ontology page view for visibility link
    link_name = 'Public' # default ontology visibility
    if ontology.summaryOnly
      link_name = 'Summary Only'
    elsif ontology.private?
      link_name = 'Private'
    elsif ontology.licensed?
      link_name = 'Licensed'
    end
    "<a href='#{ont_url}/?p=#{page_name}'>#{link_name}</a>"
  end

  def category_chip(domain)
    acronym = domain.split('/').last.strip
    begin
      category = LinkedData::Client::Models::Category.find(acronym)
      return if category.nil? || category.status == 404
    
      render ChipButtonComponent.new(
        text: acronym.upcase,
        tooltip: category.name, 
        type: "clickable",
        url: categories_browse_url(category.acronym),
        target: "_blank"
      )
    rescue => e
      Rails.logger.warn("Failed to fetch category for '#{acronym}': #{e.message}")
      nil
    end
  end

  def subject_chip(subject, theme_taxonomy_ontologies)
    resolved = resolve_subject_uri(subject, theme_taxonomy_ontologies)
    return unless resolved

    render ChipButtonComponent.new(
      text: resolved[:text].titleize,
      tooltip: subject,
      url: resolved[:url],
      type: "clickable",
      target: "_blank"
    )
  rescue => e
    Rails.logger.warn("Failed to fetch prefLabel from ontology for '#{subject}': #{e.message}")
    nil
  end

  def keyword_chip(keyword)
    render ChipButtonComponent.new(
      text: keyword.downcase,
      type: "static"
    )
  end

  def show_ontology_domains(domains)
    if domains.length == 1 && domains[0].include?(',')
      domains[0].split(',').map(&:strip)
    else
      domains
    end
  end

  def show_group_name(domain)
    return domain unless link?(domain)

    acronym = domain.split('/').last.upcase.strip
    category = LinkedData::Client::Models::Group.find(acronym)
    category ? category.name : acronym.titleize
  end


  def visits_data(ontology = nil)
    ontology ||= @ontology

    return nil unless @analytics && @analytics[ontology.acronym.to_sym]

    return @visits_data if @visits_data

    visits_data = { visits: [], labels: [] }
    years = @analytics[ontology.acronym.to_sym].to_h.keys.map { |e| e.to_s.to_i }.select { |e| e > 0 }.sort
    now = Time.now
    years.each do |year|
      months = @analytics[ontology.acronym.to_sym].to_h[year.to_s.to_sym].to_h.keys.map { |e| e.to_s.to_i }.select { |e| e > 0 }.sort
      months.each do |month|
        # No good data prior to Oct 2013
        next if now.year == year && now.month <= month || (year == 2013 && month < 10)

        visits_data[:visits] << @analytics[ontology.acronym.to_sym].to_h[year.to_s.to_sym][month.to_s.to_sym]
        visits_data[:labels] << DateTime.parse("#{year}/#{month}").strftime("%b %Y")
      end
    end
    @visits_data = visits_data
  end

  def acronyms(ontologies)
    ontologies.present? ? ontologies.map { |ont| ont.acronym } : []
  end

  def change_requests_enabled?(ontology_acronym)
    return false unless Rails.configuration.change_request[:ontologies].present?

    Rails.configuration.change_request[:ontologies].include? ontology_acronym.to_sym
  end

  def current_section
    (params[:p]) ? params[:p] : 'summary'
  end

  def link_to_section(section_title)
    link_to(section_name(section_title), ontology_path(@ontology.acronym, p: section_title),
            id: "ont-#{section_title}-tab", class: "nav-link #{selected_section?(section_title) ? 'active show' : ''}",
            data: { action: 'click->ontology-viewer-tabs#selectTab',
                    toggle: "tab", target: "#ont_#{section_title}_content", 'bp-ont-page': section_title,
                    'bp-ont-page-name': ontology_viewer_page_name(@ontology.name, @concept&.prefLabel || '', section_title) })
  end

  def selected_section?(section_title)
    current_section.eql?(section_title)
  end

  def ontology_data_sections
    LANGUAGE_FILTERABLE_SECTIONS
  end

  def ontology_data_section?(section_title = current_section)
    ontology_data_sections.include?(section_title)
  end

  def lazy_load_section?(section_title)
    !(ontology_data_section?(section_title) || section_title.eql?('summary'))
  end

  def section_data(section_title)
    if ontology_data_section?(section_title)
      url_value = selected_section?(section_title) ? request.fullpath : "/ontologies/#{@ontology.acronym}?p=#{section_title}"
      { controller: "history turbo-frame", 'turbo-frame-url-value': url_value, action: "lang_changed->history#updateURL lang_changed->turbo-frame#updateFrame" }
    else
      {}
    end
  end

  def lazy_load_section(section_title, lazy_load: true, &block)
    if current_section.eql?(section_title)
      block.call
    else
      render TurboFrameComponent.new(id: section_title, src: "/ontologies/#{@ontology.acronym}?p=#{section_title}",

                                     loading: Rails.env.development? || lazy_load ? "lazy" : "eager",
                                     target: '_top', data: { "turbo-frame-target": "frame" })
    end
  end

  def visits_chart_dataset(visits_data)
    visits_chart_dataset_array({'Visits': visits_data})
  end

  def visits_chart_dataset_array(visits_data, fill: true)
    visits_data = visits_data.map do |label , x|
      {
        label: label,
        data: x,
        borderWidth: 2,
        borderRadius: 5,
        borderSkipped: false,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        fill: fill
      }
    end
    visits_data.to_json
  end

  def submission_ready?(submission)
    Array(submission&.submissionStatus).include?('RDF')
  end

  def sections_to_show
    sections = ['summary']
    if !@ontology.summaryOnly && (submission_ready?(@submission_latest) || @old_submission_ready)
      sections += ['classes']
      sections += %w[properties]
      sections += %w[schemes collections] if skos?
      sections += %w[instances] unless skos?
      sections += %w[notes mappings widgets]
      sections << 'sparql' if sparql_enabled?
    end
    sections
  end

  def not_ready_submission_alert(ontology: @ontology, submission: @submission, old_submission_ready: @old_submission_ready)
    if ontology.admin?(session[:user])
      status = status_string(submission)
      type = nil
      message = nil
      if submission_status_error?(status)
        type = 'danger'
        message = t('ontologies.ontology_processing_failed', status: status)
      elsif submission_status_warning?(status)
        message = t('ontologies.ontology_parsing_succeeded', status: status)
        type = 'warning'

      elsif !submission_ready?(submission)
        type = 'info'
        if submission.nil?
          message = t('ontologies.upload_an_ontology', ontology: ontology_data_sections.join(', '))
        elsif old_submission_ready
          message = t('ontologies.ontology_is_processing', ontology: ontology_data_sections.join(', '))
        else
          message = t('ontologies.new_ontology_is_processing', ontology: ontology_data_sections.join(', '))
        end
      end
      render Display::AlertComponent.new(message: message, type: type, button: Buttons::RegularButtonComponent.new(id:'regular-button', value: t('ontologies.contact_support', site: "#{$SITE}"), variant: "primary", href: "/feedback", color: type, size: "slim")) if type
    end
  end

  def dispaly_complex_text(definitions)
    html = ""
    definitions.each do |definition|
      if definition.is_a?(String)
        html += '<p class="prefLabel">' + definition + '</p>'
      elsif definition.respond_to?(:uri) && definition.uri
        html +=  '<p>' + definition.uri + '</p>'
      end
    end
    return html.html_safe
  end

  def edit_sub_languages_button(ontology = @ontology, submission = @submission_latest)
    return unless ontology.admin?(session[:user])

    link = edit_ontology_submission_path(ontology.acronym, submission&.submissionId || '', properties: 'naturalLanguage', container_id: 'application_modal_content')
    link_to_modal(nil,  link, class: "btn", id:'fair-details-link',
                  data: { show_modal_title_value: t('ontologies.edit_natural_languages', acronym: ontology.acronym), show_modal_size_value: 'modal-md' }) do
      render ChipButtonComponent.new(type: 'clickable', class: 'admin-background chip_button_small' ) do
        (t('ontologies.edit_available_languages') + content_tag(:i, "", class: "fas fa-lg fa-edit")).html_safe
      end
    end
  end
  def language_selector_tag(name)
    content_language_selector(id: name, name: name)
  end

  def language_selector_hidden_tag(section)
    hidden_field_tag "language_selector_hidden_#{section}", '',
                     data: { controller: "language-change", 'language-change-section-value': section, action: "change->language-change#dispatchLangChangeEvent" }
  end

  def ontology_object_json_link(ontology_acronym, object_type, id)
    "#{rest_url}/ontologies/#{ontology_acronym}/#{object_type}/#{escape(id)}?display=all"
  end

  def render_permalink_link
    content_tag(:div, class: 'mx-1') do
      link_to("#classPermalinkModal", class: "class-permalink nav-link", title: t('concepts.permanent_link_class'), aria: { label: t('concepts.permanent_link_class') }, data: { toggle: "modal", current_purl: @current_purl }) do
        content_tag(:i, '', class: "fas fa-link", aria: { hidden: "true" })
      end
    end
  end

  def render_concepts_json_button(link)
    link, target = api_button_link_and_target(link)
    content_tag(:div, class: 'concepts_json_button') do
      render RoundedButtonComponent.new(link: link, target: target)
    end
  end


  def ontology_object_details_component(frame_id: , ontology_id:, objects_title:, object:, &block)
    render TurboFrameComponent.new(id: frame_id, data: {"turbo-frame-target": "frame"}) do
      return unless object.present?

      if object.errors
        alert_component(object.errors.join)
      else
        ontology_object_tabs_component(ontology_id: ontology_id, objects_title: objects_title, object_id: object["@id"]) do |tabs|
          tab_item_component(container_tabs: tabs, title: t('concepts.details'), path: '#details', selected: true) do
            capture(&block)
          end
        end
      end
    end
  end

  def ontology_object_tabs_component(ontology_id:, objects_title:, object_id:, &block)
    resource_url = ontology_object_json_link(ontology_id, objects_title, object_id)
    render TabsContainerComponent.new(type: 'outline') do |c|
      concat(c.pinned_right do
        content_tag(:div, '', 'data-concepts-json-target': 'button') do
          concat(render_permalink_link) if $PURL_ENABLED
          concat(render_concepts_json_button(resource_url))
        end
      end)

      capture(c, &block)
    end
  end


  def display_complex_text(definitions)
    html = ""
    definitions.each do |definition|
      if definition.is_a?(String)
        html += '<p class="prefLabel">' + definition + '</p>'
      elsif definition.respond_to?(:uri) && definition.uri
        html += render LinkFieldComponent.new(value: definition.uri)
      else
        html += display_in_multiple_languages(definition)
      end
    end
    return html.html_safe
  end

  def new_view_path(ont_id)
    ont_id_esc = CGI.escape(ont_id)
    if session[:user].nil?
      "/login?redirect=#{escape("/ontologies/new?ontology[viewOf]=#{ont_id_esc}")}"
    else
      "/ontologies/new?ontology[viewOf]=#{ont_id_esc}"
    end
  end

  def new_element_link(title, link)
    if session[:user].nil?
      link = "/login?redirect=#{link}"
    end

    link_to(link, title: title, class: "mx-1") do
      inline_svg_tag("icons/plus.svg", width: '15px', height: '15px', class: 'add-views-plus-icon')
    end
  end

  def ontology_icon_links(links, submission_latest)
    links.map do |icon, attr, label|
      value = submission_latest.nil? ? nil : submission_latest.send(attr)
      link = Array(value).first || ''

      link_options = {
        style: "text-decoration: none; width: 30px; height: 30px"
      }

      if link.blank?
        link_options[:class] = 'disabled-icon'
        link_options[:disabled] = 'disabled'
        title = label
      else
        title = label + '<br>' + link_to(link, target: '_blank')
      end

      url, target_attr = api_button_link_and_target(link || '', allow_annonymous = true)
      content_tag(:span, data: {controller: "tooltip" }, title: title) do
        link_to(inline_svg("#{icon}.svg", width: "32", height: '32'), url, link_options.merge(target: target_attr))
      end
    end.join.html_safe
  end

  def ontology_depiction_card
    depictions = Array(@submission_latest&.depiction)
    return if depictions.empty?

    render Layout::CardComponent.new do
      if depictions.size == 1
        render Display::ImageComponent.new(src: depictions.first)
      else
        render CarouselComponent.new(images: true) do |c|
          depictions.each do |url|
            c.slide { render Display::ImageComponent.new(src: url) }
          end
        end
      end
    end
  end

  def count_subscriptions(ontology_id)
    ontology_id = ontology_id.split('/').last
    users = LinkedData::Client::Models::User.all(include: 'all', display_context: false, display_links: false)
    users.select { |u| u.subscription.find { |s| s.ontology && s.ontology.split('/').last.eql?(ontology_id) } }.count
  end

  def new_submission_button
    return unless @ontology.admin?(session[:user])
    render RoundedButtonComponent.new(link: new_ontology_submission_path(@ontology.acronym), icon: 'icons/plus.svg',
                                      size: 'medium', title: t('ontologies.add_new_submission'))
  end

  def ontology_admin_button
    return unless @ontology.admin?(session[:user])
    render RoundedButtonComponent.new(link: ontology_administration_path(@ontology.acronym), icon: 'icons/settings.svg',
                                      size: 'medium', title: t('ontologies.admin.title'))
  end

  def ontology_edit_button
    return unless @ontology.admin?(session[:user])
    render RoundedButtonComponent.new(link: edit_ontology_submission_path(ontology_id: @ontology.acronym, id: @submission_latest.id.split('/').last), icon: 'edit.svg',
                                      size: 'medium',
                                      title: t('ontologies.edit_metadata'))
  end

  def upload_ontology_button
    return if read_only_enabled?

    href = if session[:user].nil?
             "/login?redirect=#{new_ontology_path}"
           else
             new_ontology_path
           end

    render = regular_button(
      "upload-ontology-button",
      t('home.ontology_upload_button'),
      variant: "secondary",
      state: "regular",
      size: nil,
      href: href) do |btn|
        btn.icon_left do
          inline_svg_tag "upload.svg"
        end
      end
    end

  def submission_json_button
    link = "#{(@submission_latest || @ontology).id}?display=all"
    link, target = api_button_link_and_target(link)
    render RoundedButtonComponent.new(link: link,
                                      target: target,
                                      size: 'medium',
                                      title: t('ontologies.go_to_api'))
  end


  def projects_field(projects, ontology_acronym = @ontology.acronym)
    render FieldContainerComponent.new do |f|
      f.label do
        concat t('ontologies.projects_using_ontology', acronym: ontology_acronym)
        concat new_element_link(t('ontologies.create_new_project'), new_project_path)
      end

      if projects.empty?
        empty_state_message(t('ontologies.no_projects_using_ontology', acronym: ontology_acronym))
      else
        horizontal_list_container(projects) do |project|
          render ChipButtonComponent.new(url: project_path(project.acronym), text: project.name, type: "clickable")
        end
      end
    end
  end
  def ontology_import_code(submission = @submission_latest )
    # TODO remove or reuse somewhere elese
    prefix = submission.preferredNamespacePrefix
    namespace= submission.preferredNamespaceUri || submission.URI
    return if prefix.blank? && namespace.blank?

    render ChipButtonComponent.new do
      concat content_tag(:span , "@prefix ", style: 'color: #FA7070')
      concat content_tag(:span , "#{prefix}: ", style: 'color: var(--primary-color);font-weight: 700;')
      concat content_tag(:span , "<#{namespace}>", style: 'color:#9999a9;')
    end
  end

  def metadata_vocabulary_display(vocabularies)
    vocabularies_data = attribute_enforced_values('metadataVoc')
    horizontal_list_container(vocabularies) do |voc|
      tooltip = vocabularies_data[voc] || nil
      tooltip = "#{tooltip} (#{link_to(voc)})" if tooltip
      label = prefix_property_url(voc, nil) || voc

      label =  content_tag(:span, data: {controller:'tooltip'}, title: tooltip) do
        render(ExternalLinkTextComponent.new(text: label))
      end
      render ChipButtonComponent.new(url: voc, text: label, type: 'clickable')
    end
  end

  def summary_only?
    @ontology&.summaryOnly || @submission&.isRemote&.eql?('3')
  end

  def ontology_pull_location?
    !(@submission.pullLocation.nil? || @submission.pullLocation.empty?)
  end

  def generate_link_title
    inside_color = 'var(--primary-color)'
    outside_color = '#007bff'

    inside_span = content_tag(:span, "#{portal_name}", style: "color: #{inside_color} !important;")
    outside_span = content_tag(:span, t('ontologies.outside'), style: "color: #{outside_color};")

    link_title = t('ontologies.relation_with_other_ontologies', inside: inside_span, outside: outside_span).html_safe
  end


  def edit_button(link:, title: )
    render IconWithTooltipComponent.new(icon: "edit.svg",link: link, target: '_blank', title: title)
  end

  def service_button(link:, title: )
    link, target = api_button_link_and_target(link)
    render IconWithTooltipComponent.new(icon: "json.svg",link: link, target: target, title: title)
  end

  def n_triples_to_table(n_triples_string)
    grouped_by_id = n_triples_string.split(".\n").map do |x|
      x.strip.scan(/^<([^>]+)> <([^>]+)> (.+)/).flatten
    end.group_by { |x| x.shift }

    grouped_by_id_and_properties = grouped_by_id.transform_values do |x|
      x.group_by { |y| y.shift }
    end

    render TableComponent.new do |t|
      resource_id, resource_id_values = grouped_by_id_and_properties.shift

      t.add_row({ td: "ID" }, { td: resource_id })

      resource_id_values.each do |property, values|
        t.row do |row|
          url = property.gsub(/[<>]/, '')
          row.td do
            content_tag(:span, prefixed_url(url), title: link_to(url, url), 'data-controller': 'tooltip')
          end

          row.td do
            horizontal_list_container(values.flatten) do |v|
              v = v.strip.match?(/^<(.+)>/) ? v.strip.match(/^<(.+)>/)[1] : v
              link?(v) ? render(LinkFieldComponent.new(value: v)) : "#{v}, "
            end
          end
        end
      end

      inverse_grouped_by_properties = grouped_by_id_and_properties.transform_values(&:to_a)
                                                                  .to_a
                                                                  .map(&:flatten)
                                                                  .group_by { |x| x.delete_at(1) }
      inverse_grouped_by_properties.each do |property, values|
        t.row do |row|
          url = property.gsub(/[<>]/, '')
          row.td do
            content_tag(:span, prefixed_url(url), title: link_to(url, url), 'data-controller': 'tooltip')
          end

          row.td do
            horizontal_list_container(values.flatten) do |v|
              v = v.strip.match?(/^<(.+)>/) ? v.strip.match(/^<(.+)>/)[1] : v
              next if v.eql?(resource_id)

              link?(v) ? render(LinkFieldComponent.new(value: v)) : "#{v}, "
            end
          end
        end
      end

    end
  end


  def submission_languages(submission = @submission)
    Array(submission&.naturalLanguage).map { |natural_language| natural_language["iso639"] && natural_language.split('/').last }.compact
  end

  def browse_taxonomy_tooltip(taxonomy_type)
    return nil unless taxonomy_type.eql?("categories") || taxonomy_type.eql?("groups")

    content_tag(:div, class: '') do
      content_tag(:span, t('ontologies.taxonomy_information_tooltip', taxonomy_type: taxonomy_type), class: 'mr-1') +
        content_tag(:a, 'here', href: "/#{taxonomy_type}", target: '_blank')
    end
  end

  def browse_chip_filter(key:, object:, values:, countable: true, count: nil)
    title = (key.to_s.eql?("categories") || key.to_s.eql?("groups")) ? nil : ''
    checked = values.any? { |obj| [link_last_part(object["id"]), link_last_part(object["value"])].include?(obj) }
    content_tag(:div, (key.to_s.eql?("categories") ? { 'data-action' => 'click->parent-categories-selector#check' } : {})) do
      group_chip_component(name: key, object: object, checked: checked, title: title) do |c|
        c.count { browse_chip_count_badge(key: key, id: object["id"], count: count) } if countable
      end
    end
  end

  def browse_chip_count_badge(id:, key:, count: nil)
    content_tag :span, class: 'badge badge-light ml-1' do
      turbo_frame_tag("count_#{key}_#{link_last_part(id)}", busy: true) +
        if count || count == 0
          content_tag(:span, count.to_s, class: "hide-if-loading #{count.zero? ? 'disabled' : ''}")
        else
          content_tag(:span, class: 'show-if-loading') do
            loader_component(small: true, type: nil)
          end
        end
    end
  end

  def browse_filter_section_label(key)
    labels = {
      categories: t('ontologies.categories'),
      groups: t('ontologies.groups'),
      hasFormalityLevel: t('ontologies.formality_levels'),
      isOfType: t('ontologies.ontology_types'),
      naturalLanguage: t('ontologies.natural_languages')
    }

    labels[key] || key.to_s.underscore.humanize.capitalize
  end

  def browse_filter_section_header(key: nil, count: nil, title: nil)
    render Display::HeaderComponent.new(tooltip: key ? browse_taxonomy_tooltip(key.to_s) : nil) do
      content_tag(:span, class: "browse-filter-title-bar") do
        concat title || browse_filter_section_label(key)

        concat content_tag(:span, count, class: "badge badge-primary mx-1",
                           "data-show-filter-count-target": "countSpan",
                           style: "#{count&.positive? ? '' : 'display: none;'}")
      end

    end
  end

  def browse_filter_section_body(checked_values: , key:, objects:, countable: true, counts: nil)
    output = content_tag(:div, class: "browse-filter-checks-container px-3")  do
      Array(objects).map do |object|
        count = counts ? counts[link_last_part(object["id"])] || 0 : nil
        concat browse_chip_filter(key: key, object: object, values: checked_values, countable: countable, count: count)
      end
    end

    if key.to_s.include?("categories")
      turbo_frame_tag('categories_refresh_for_federation') { output.html_safe }
    else
      output
    end
  end

  def browser_counter_loader
    content_tag(:div, class: "browse-desc-text", style: "margin-bottom: 15px;") do
      content_tag(:div, class: "d-flex align-items-center") do
        str = content_tag(:span, t('ontologies.showing'))
        str += content_tag(:span, "", class: "p-1 p-2", style: "color: #a7a7a7;") do
          render LoaderComponent.new(small: true)
        end
        str
      end
    end
  end

end
