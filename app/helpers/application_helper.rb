# Methods added to this helper will be available to all templates in the application.

require 'uri'
require 'cgi'
require 'digest/sha1'
require 'pry' # used in a rescue

module ApplicationHelper
  REST_URI = $REST_URL
  API_KEY = $API_KEY

  include ModalHelper, MultiLanguagesHelper, UrlsHelper, ComponentsHelper


  RESOLVE_NAMESPACE = {:omv => "http://omv.ontoware.org/2005/05/ontology#", :skos => "http://www.w3.org/2004/02/skos/core#", :owl => "http://www.w3.org/2002/07/owl#",
                       :rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", :rdfs => "http://www.w3.org/2000/01/rdf-schema#", :metadata => "http://data.bioontology.org/metadata/",
                       :metadata_def => "http://data.bioontology.org/metadata/def/", :dc => "http://purl.org/dc/elements/1.1/", :xsd => "http://www.w3.org/2001/XMLSchema#",
                       :oboinowl_gen => "http://www.geneontology.org/formats/oboInOwl#", :obo_purl => "http://purl.obolibrary.org/obo/",
                        :umls => "http://bioportal.bioontology.org/ontologies/umls/", :door => "http://kannel.open.ac.uk/ontology#", :dct => "http://purl.org/dc/terms/",
                        :void => "http://rdfs.org/ns/void#", :foaf => "http://xmlns.com/foaf/0.1/", :vann => "http://purl.org/vocab/vann/", :adms => "http://www.w3.org/ns/adms#",
                        :voaf => "http://purl.org/vocommons/voaf#", :dcat => "http://www.w3.org/ns/dcat#", :mod => "http://www.isibang.ac.in/ns/mod#", :prov => "http://www.w3.org/ns/prov#",
                        :cc => "http://creativecommons.org/ns#", :schema => "http://schema.org/", :doap => "http://usefulinc.com/ns/doap#", :bibo => "http://purl.org/ontology/bibo/",
                       :wdrs => "http://www.w3.org/2007/05/powder-s#", :cito => "http://purl.org/spar/cito/", :pav => "http://purl.org/pav/", :nkos => "http://w3id.org/nkos/nkostype#",
                       :oboInOwl => "http://www.geneontology.org/formats/oboInOwl#", :idot => "http://identifiers.org/idot/", :sd => "http://www.w3.org/ns/sparql-service-description#",
                       :cclicense => "http://creativecommons.org/licenses/",
                       'skos-xl' => "http://www.w3.org/2008/05/skos-xl#"}

  def search_json_link(link = @json_url, style: '')
    custom_style = "font-size: 50px; line-height: 0.5; margin-left: 6px; #{style}".strip
    link, target = api_button_link_and_target(link)
    render IconWithTooltipComponent.new(icon: "json.svg",link: link, target: target, title: t('fair_score.go_to_api'), size:'small', style: custom_style)
  end

  def read_only_enabled?
    $READ_ONLY_PORTAL && !current_user_admin?
  end
  
  def agents_enabled?
    user = current_user rescue nil
    Flipper.enabled?('Agents', user)
  end

  def sparql_enabled?
    user = current_user rescue nil
    Flipper.enabled?('SPARQL', user) && $SPARQL_ENDPOINT_URL
  end
  def sidekiq_enabled?
    user = current_user rescue nil
    Flipper.enabled?('SIDEKIQ_UI', user) && $SIDEKIQ_UI_URL
  end
  def portal_name_from_uri(uri)
    URI.parse(uri).hostname.split('.').first
  end

  def resolve_namespaces
    RESOLVE_NAMESPACE
  end

  def ontologies_analytics
    begin
      data = LinkedData::Client::Analytics.last_month.onts
      data.map{|x| [x[:ont].split('/').last.to_s, x[:views]]}.to_h
    rescue StandardError
      {}
    end
  end

  def get_apikey
    unless session[:user].nil?
      return session[:user].apikey
    else
      return LinkedData::Client.settings.apikey
    end
  end

  def api_button_link_and_target(link, allow_annonymous = false)
    if current_user.nil? && !allow_annonymous
      ["/login?redirect=#{escape(link)}", '_top']
    else
      link = append_apikey_if_rest_url(link, current_user)
      [link, '_blank']
    end
  end

  def omniauth_providers_info
    $OMNIAUTH_PROVIDERS
  end

  def omniauth_provider_info(strategy)
    omniauth_providers_info.select {|k,v| v[:strategy].eql?(strategy.to_sym) || k.eql?(strategy)}
  end

  def omniauth_token_provider(strategy)
    omniauth_provider_info(strategy.to_sym).keys.first
  end

  def current_user
    # Safely return session[:user] or nil if no session context
    return nil unless respond_to?(:session) && session
    session[:user]
  end

  def current_user_admin?
    session[:user] && session[:user].admin?
  end

  def child_id(child)
    child.id.to_s.split('/').last
  end

  def help_tooltip(content, html_attribs = {}, icon = 'fas fa-question-circle', css_class = nil, text = nil)
    html_attribs["title"] = content
    attribs = []
    html_attribs.each {|k,v| attribs << "#{k.to_s}='#{v}'"}
    return <<-BLOCK
          <a data-controller='tooltip' class='pop_window tooltip_link d-inline-block #{[css_class].flatten.compact.join(' ')}' #{attribs.join(" ")}>
            <i class="#{icon} d-flex"></i> #{text}
          </a>
    BLOCK
  end

  def error_message_text
    return @errors if @errors.is_a?(String)
    @errors = @errors[:error] if @errors && @errors[:error]
    t('application.errors_in_fields', errors: @errors.keys.join(', '))
  end

  def error_message_alert
    return if @errors.nil?

    content_tag(:div, class: 'my-1') do
      render Display::AlertComponent.new(message: error_message_text, type: 'danger', closable: false)
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

  def slices_enabled?
    $ENABLE_SLICES.eql?(true)
  end

  def at_slice?
    !@subdomain_filter.nil? && !@subdomain_filter[:active].nil? && @subdomain_filter[:active] == true
  end

  def add_comment_button(parent_id, parent_type)
    if session[:user].nil?
      link_to t('application.add_comment'),  login_index_path(redirect: request.url), class: "secondary-button regular-button slim", data: {'turbo-frame': '_top'}
    else
      link_to_modal t('application.add_comment'), notes_new_comment_path(parent_id: parent_id, parent_type: parent_type, ontology_id: @ontology.acronym),
                    class: "secondary-button regular-button slim", data: { show_modal_title_value: t('application.add_new_comment')}
    end
  end

  def add_reply_button(parent_id)
    if session[:user].nil?
      link_to t('application.reply'), login_index_path, 'data-turbo': false
    else
      link_to t('application.reply'), notes_new_reply_path(parent_id: parent_id ), "data-turbo-frame": "#{parent_id}_new_reply"
    end
  end

  def add_proposal_button(parent_id, parent_type)
    if session[:user].nil?
      link_to t('application.add_proposal'),  login_index_path(redirect: request.url), class: "secondary-button regular-button slim",  data: {'turbo-frame': '_top'}
    else
      link_to_modal t('application.add_proposal'), notes_new_proposal_path(parent_id: parent_id, parent_type: parent_type, ontology_id: @ontology.acronym),
                    class: "secondary-button regular-button slim", data: { show_modal_title_value: t('application.add_new_proposal')}
    end
  end

  def subscribe_button(ontology_id)
    return if ontology_id.nil?
    render TurboFrameComponent.new(id: 'subscribe_button', src: ontology_subscriptions_path(ontology_id: ontology_id.split('/').last), class: 'ml-1') do |t|
      t.loader do
        content_tag(:div, style: 'margin-left: 10px;') do
          render PillButtonComponent.new do
            (content_tag(:span, t('application.watching'), class: 'ml-1') + render(LoaderComponent.new(small: true))).html_safe
          end
        end
      end
    end
  end

  def admin_block(ontology: @ontology, user: session[:user], class_css: "admin-border", &block)
    if ontology.admin?(user)
      content_tag(:div, class: class_css) do
        capture(&block) if block_given?
      end
    end
  end

  def subscribed_to_ontology?(ontology_acronym, user)
    user = LinkedData::Client::Models::User.find(user.username, {include: 'all'}) if user.subscription.nil?
    return false if user.subscription.nil? or user.subscription.empty?
    user.subscription.each do |sub|
      sub_ont_acronym = sub[:ontology] ?  sub[:ontology].split('/').last : nil #  make sure we get the acronym, even if it's a full URI
      return true if sub_ont_acronym == ontology_acronym
    end
    return false
  end

  # http://stackoverflow.com/questions/1293573/rails-smart-text-truncation
  def smart_truncate(s, opts = {})
    opts = {:words => 20}.merge(opts)
    if opts[:sentences]
      return s.split(/\.(\s|$)+/)[0, opts[:sentences]].map{|s| s.strip}.join('. ') + '. ...'
    end
    a = s.split(/\s/) # or /[ ]+/ to only split on spaces
    n = opts[:words]
    a[0...n].join(' ') + (a.size > n ? '...' : '')
  end

  # convert xml_date_time_str from triple store into "mm/dd/yyyy", e.g.:
  # parse_xmldatetime_to_date( '2010-06-27T20:17:41-07:00' )
  # => '06/27/2010'
  def xmldatetime_to_date(xml_date_time_str)
    require 'date'
    d = DateTime.xmlschema( xml_date_time_str ).to_date
    # Return conventional US date format:
    return sprintf("%02d/%02d/%4d", d.month, d.day, d.year)
    # Or return "yyyy/mm/dd" format with:
    #return DateTime.xmlschema( xml_date_time_str ).to_date.to_s
  end

  def notification_type(flash_key)
    bootstrap_alert_class = {
      'notice' => 'success',
      'success' => 'success',
      'error' => 'error',
      'alert' => 'alert'
    }
    bootstrap_alert_class[flash_key]
  end

  def label_ajax_link(id, ont_acronym, ajax_uri, target)
    ajax_uri = if ajax_uri.include?('?')
                 "#{ajax_uri}&ontology=#{ont_acronym}&id=#{escape(id)}"
               else
                 "#{ajax_uri}?ontology=#{ont_acronym}&id=#{escape(id)}"
               end

    content_tag(:span, class: 'concepts-mapping-count') do
      ajax_link_chip(id, ajax_src: ajax_uri, target: target)
    end
  end

  def get_link_for_cls_ajax(cls_id, ont_acronym, target = nil)
    if cls_id.start_with?('http://') || cls_id.start_with?('https://')
      ajax_url = '/ajax/classes/label'
      label_ajax_link(cls_id, ont_acronym, ajax_url, target)
    else
      content_tag(:div, cls_id)
    end
  end

  def get_link_for_scheme_ajax(scheme, ont_acronym, target = '_blank')
    ajax_url = "/ajax/schemes/label?language=#{request_lang}"
    label_ajax_link(scheme, ont_acronym, ajax_url, target)
  end

  def get_link_for_collection_ajax(collection, ont_acronym, target = '_blank')
    ajax_url = "/ajax/collections/label?language=#{request_lang}"
    label_ajax_link(collection, ont_acronym, ajax_url, target)
  end

  def get_link_for_label_xl_ajax(label_xl, ont_acronym, cls_id, target = nil)
    ajax_url = "/ajax/label_xl/label?cls_id=#{CGI.escape(cls_id)}"
    label_ajax_link(label_xl, ont_acronym, ajax_url, target)
  end

  def ontology_viewer_page_name(ontology_name, concept_label, page)
    ontology_name + " | "  + " #{page.capitalize}"
  end

  def help_path(anchor: nil)
    "#{Rails.configuration.settings.links[:help]}##{anchor}"
  end

  def extract_label_from(uri)
    label = uri.to_s.chomp('/').chomp('#')
    index = label.index('#')
    if !index.nil?
      label = label[(index + 1) , uri.length-1]
    else
      index = label.rindex('/')
      label = label[(index + 1), uri.length-1]  if index > -1 && index < (uri.length - 1)
    end
    label
  end

  def skos?
    submission = @submission || @submission_latest
    submission&.hasOntologyLanguage === 'SKOS'
  end

  def current_page?(path)
    request.path.eql?(path)
  end

  def bp_config_json
    # For config settings, see
    # config/bioportal_config.rb
    # config/initializers/ontologies_api_client.rb
    config = {
      org: $ORG,
      org_url: $ORG_URL,
      site: $SITE,
      org_site: $ORG_SITE,
      ui_url: $UI_URL,
      apikey: LinkedData::Client.settings.apikey,
      userapikey: get_apikey,
      rest_url: LinkedData::Client.settings.rest_url,
      proxy_url: $PROXY_URL,
      biomixer_url: $BIOMIXER_URL,
      annotator_url: $ANNOTATOR_URL,
      ncbo_annotator_url: $NCBO_ANNOTATOR_URL,
      ncbo_apikey: $NCBO_API_KEY,
      interportal_hash: $INTERPORTAL_HASH,
      resolve_namespace: RESOLVE_NAMESPACE
    }
    config[:ncbo_slice] = @subdomain_filter[:acronym] if (@subdomain_filter[:active] && !@subdomain_filter[:acronym].empty?)
    config.to_json
  end

  def portal_name
    $SITE
  end

  def current_slice_name
    name = @subdomain_filter[:name]
    name.blank? ? nil : name
  end

  def navitems
    items = [["/ontologies", t('layout.header.browse')],
             ["/mappings", t('layout.header.mappings')],
             ["/recommender", t("layout.header.recommender")],
             ["/annotator", t("layout.header.annotator")],
             ["/projects", t('application.projects')]]
  end

  def beta_badge(text = t('application.beta_badge_text'), tooltip: t('application.beta_badge_tooltip'))
    return unless text
    content_tag(:span, text, data: { controller: 'tooltip' }, title: tooltip, class: 'badge badge-pill bg-secondary text-white')
  end

  def attribute_enforced_values(attr)
    submission_metadata.select {|x| x['@id'][attr]}.first['enforcedValues']
  end

  def prefix_properties(concept_properties)
    modified_properties = {}

    concept_properties&.each do |key, value|
      if value.is_a?(Hash) && value.key?(:key)
        key_string = value[:key].to_s
        next if key_string.include?('metadata')

        modified_key = prefix_property_url(key_string, key)

        if modified_key
          modified_properties[modified_key] = value
        else
          modified_properties[link_last_part(key_string)] = value
        end

      end
    end

    modified_properties
  end

  def rest_url
    # Split the URL into protocol and path parts
    protocol, path = $REST_URL.split("://", 2)

    # Remove the last '/' in the path part
    cleaned_path = path.chomp('/')
    # Reconstruct the cleaned URL
    "#{protocol}://#{cleaned_path}"
  end

  def sidekiq_ui_url
    sidekiq_ui_url = $SIDEKIQ_UI_URL
  end
  
  def categories_browse_url(category)
    ontologies_path(categories: category)
  end

  def prefix_property_url(key_string, key = nil)
    namespace_key, _ = RESOLVE_NAMESPACE.find { |_, value| key_string.include?(value) }

    if key && namespace_key
      "#{namespace_key}:#{key}"
    elsif key.nil? && namespace_key
      namespace_key
    else # we don't try to guess the prefix
      nil
    end
  end

  def prefixed_url(url)
    key = link_last_part(url)
    prefix_property_url(url.split(key).first, key)
  end

  def show_advanced_options_button(text: nil, init: nil)
    content_tag(:div, class: "#{init ? 'd-none' : ''} advanced-options-button", 'data-action': 'click->reveal-component#show', 'data-reveal-component-target': 'showButton') do
      inline_svg_tag('icons/settings.svg') +
        content_tag(:div, text, class: 'text')
    end
  end

  def hide_advanced_options_button(text: nil, init: nil)
    content_tag(:div, class: "#{init ? '' : 'd-none'} advanced-options-button", 'data-action': 'click->reveal-component#hide', 'data-reveal-component-target': 'hideButton') do
      inline_svg_tag('icons/hide.svg') +
        content_tag(:div, text, class: 'text')
    end
  end

  def insert_sample_text_button(text)
    content_tag(:div, class:'insert-sample-text-button') do
      content_tag(:div, class: 'button', 'data-action': 'click->sample-text#annotator_recommender', 'data-sample-text': t("annotator.sample_text")) do
        content_tag(:div, text, class: 'text') +
        inline_svg_tag('icons/arrow-curved-up.svg')
      end
    end
  end

  def empty_state(text: t('no_result_was_found'))
    render Display::EmptyStateComponent.new(text: text)
  end

  def ontologies_selector(id:, label: nil, name: nil, selected: nil, placeholder: nil, multiple: true, ontologies: onts_for_select, show_advanced_options: true)
    content_tag(:div) do
      render(Input::SelectComponent.new(id: id, label: label, name: name, value: ontologies, multiple: multiple, selected: selected, placeholder: placeholder)) +
      content_tag(:div, class: 'ontologies-selector-button', 'data-controller': 'ontologies-selector', 'data-ontologies-selector-id-value': id) do      
        content_tag(:div, t('ontologies_selector.clear_selection'), class: 'clear-selection', 'data-action': 'click->ontologies-selector#clear') +
        (show_advanced_options ? link_to_modal(t('ontologies_selector.ontologies_advanced_selection'), "/ontologies_selector?id=#{id}", data: { show_modal_title_value: t('ontologies_selector.ontologies_advanced_selection') }) : ''.html_safe)
      end
    end
  end

  def link_button_component(href: , value: , id:, size: nil, variant: 'primary')
    render Buttons::RegularButtonComponent.new(id:id, value: value, variant: variant, type: 'link', href: href, size: size)
  end

  def save_button_component(class_name: nil, id: , value:, data: nil, size: nil, type: nil)
    content_tag(:div, data: data, class: class_name) do
      render Buttons::RegularButtonComponent.new(id:id, value: value, variant: "primary", state: 'regular', size: size, type: type) do |btn|
        btn.icon_right do
          inline_svg_tag "check.svg"
        end
      end
    end
  end

  def cancel_button_component(class_name: nil, id: , value:, data: nil)
    content_tag(:div, data: data, class: class_name) do
      render Buttons::RegularButtonComponent.new(id:id, value: value, variant: "secondary", state: 'regular') do |btn|
        btn.icon_left do
          inline_svg_tag "x.svg"
        end
      end
    end
  end

  def categories_select(id: nil, name: nil, selected: 'None')
    categories_for_select = LinkedData::Client::Models::Category.all.map{|x| ["#{x.name} (#{x.acronym})", x.id]}.unshift(["None", ''])
    render Input::SelectComponent.new(id: id, name: name, value: categories_for_select, selected: selected, multiple: true)
  end

  def category_is_parent?(parents_list, category)
    # Handle nil or empty parents_list
    return [false, ''] unless parents_list.respond_to?(:keys)

    is_parent = parents_list.keys.include?(category.id)
    parent_error_message = t('admin.categories.category_used_parent')
    parents_list[category.id].each do |c|
      parent_error_message = "#{parent_error_message} #{c}"
    end
    [is_parent,parent_error_message]
  end

  def categories_with_children(categories)
    parent_to_children = Hash.new { |hash, key| hash[key] = [] }
    categories.each do |category|
      next unless category.parentCategory
      category.parentCategory.each do |parent_id|
        parent_acronym = id_to_acronym(parent_id)
        child_acronym = id_to_acronym(category.id)
        parent_to_children[parent_acronym] << child_acronym
      end
    end
    parent_to_children
  end

  def categories_with_parents(categories_children)
    categories_parents = Hash.new { |hash, key| hash[key] = [] }
    categories_children.each do |child, parents|
      parents.each do |parent|
        categories_parents[parent] << child
      end
    end
    categories_parents
  end

  def id_to_acronym(id)
    id.split('/').last
  end

  private

  def append_apikey_if_rest_url(link, user = current_user)
    return link if link.blank? 
    rest_url = LinkedData::Client.settings.rest_url
    fairness_url = $FAIRNESS_URL
    if link.include?(rest_url) || (fairness_url.present? && link.include?(fairness_url))
      uri = URI.parse(link) rescue nil
      return link unless uri
      params = URI.decode_www_form(uri.query || "")
      params.reject! { |k, v| k == "apikey" }
      params << ["apikey", get_apikey]
      uri.query = URI.encode_www_form(params)
      link = uri.to_s
    end
    link
  end

end
