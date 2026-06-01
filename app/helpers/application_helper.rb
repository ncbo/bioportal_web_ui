require 'uri'
require 'cgi'
require 'digest/sha1'

module ApplicationHelper
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

  def link?(str)
    # Regular expression to match strings starting with "http://" or "https://"
    link_pattern = /\Ahttps?:\/\//
    str = str&.strip
    # Check if the string matches the pattern
    !!(str =~ link_pattern)
  end

  def get_apikey
    unless session[:user].nil?
      session[:user].apikey
    else
      LinkedData::Client.settings.apikey
    end
  end

  def child_id(child)
    child.id.to_s.split('/').last
  end

  def escape(url)
    CGI.escape(url) if url
  end

  def portal_name
    $SITE || 'BioPortal'
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


  def empty_state(text: t('no_result_was_found'))
    render Display::EmptyStateComponent.new(text: text)
  end

  def section_name(section)
    section = concept_label_to_show(submission: @submission_latest || @submission) if section.eql?('classes')
    t("ontology_details.sections.#{section}")
  end

  def skos?
    submission = @submission || @submission_latest
    submission&.hasOntologyLanguage === 'SKOS'
  end

  def clean(string)
    string = string.gsub("\"", '\'')
    string.gsub("\n", '')
  end

  def clean_id(string)
    string.gsub(':', '').gsub('-', '_').gsub('.', '_')
  end

  def get_username(user_id)
    user_id.split('/').last
  end

  def current_user_admin?
    session[:user] && session[:user].admin?
  end

  def remove_owl_notation(string)
    # TODO_REV: No OWL notation, but should we modify the IRI?
    string
  end

  def rest_url
    # Split the URL into protocol and path parts
    protocol, path = $REST_URL.split("://", 2)

    # Remove the last '/' in the path part
    cleaned_path = path.chomp('/')
    # Reconstruct the cleaned URL
    "#{protocol}://#{cleaned_path}"
  end


  def draw_tree(root, id = nil, submission = @submission || @submission_latest)
    if id.nil?
      id = root.children.first.id
    end
    # TODO: handle tree view for obsolete classes, e.g. 'http://purl.obolibrary.org/obo/GO_0030400'
    raw build_tree(root, "", id, submission)  # returns a string, representing nested list items
  end

  def build_tree(node, string, id, submission)
    if node.children.nil? || node.children.length < 1
      return string # unchanged
    end
    node.children.sort! { |a, b| (a.prefLabel || a.id).downcase <=> (b.prefLabel || b.id).downcase }
    for child in node.children
      if child.id.eql?(id)
        active_style = "class='tree-link active'"
      else
        active_style = ""
      end

      # This fake root will be present at the root of "flat" ontologies, we need to keep the id intact
      li_id = child.id.eql?('bp_fake_root') ? 'bp_fake_root' : short_uuid
      lang = request_lang(submission)
      ontology_acronym = submission.ontology.acronym
      if child.id.eql?('bp_fake_root')
        string << tree_link_to_concept(li_id: li_id, child: child, ontology_acronym: '',
                                       active_style: active_style, lang: lang)
      else
        string << tree_link_to_concept(li_id: li_id, child: child, ontology_acronym: ontology_acronym,
                                       active_style: active_style, lang: lang)

        if child.hasChildren && !child.expanded?
          string << tree_link_to_children(li_id: li_id, child: child, ontology_acronym: ontology_acronym, lang: lang)
        elsif child.expanded?
          string << '<ul>'
          build_tree(child, string, id, submission)
          string << '</ul>'
        end
        string << '</li>'
      end
    end

    string
  end


  def tree_link_to_concept(li_id:, child:, ontology_acronym:, active_style:, lang: )
    page_name = ontology_viewer_page_name(ontology_acronym, main_language_label(child.prefLabel), 'Classes')
    open = child.expanded? ? "class='open'" : ''
    pref_label_html, tooltip = tree_node_label(child)
    href = ontology_acronym.blank? ? '#' :  "/ontologies/#{ontology_acronym}/concepts/?id=#{CGI.escape(child.id)}&lang=#{lang}"
    "<li #{open} id='#{li_id}'><a id='#{CGI.escape(child.id)}' data-bp-ont-page-name='#{page_name}' data-turbo=true data-turbo-frame='concept_show' href='#{href}' #{active_style} title='#{tooltip}'> #{pref_label_html}</a>"
  end

  def tree_node_label(child)
    label = begin
              child.prefLabel || child.label
            rescue
              child.id
            end

    if label.nil?
      pref_label_html = link_last_part(child.id)
    else
      pref_label_lang, pref_label_html = select_language_label(label)
      pref_label_lang = pref_label_lang.to_s.upcase
      tooltip = pref_label_lang.eql?("@NONE") ? "" : pref_label_lang

      pref_label_html = "<span class='obsolete_class'>#{pref_label_html.html_safe}</span>".html_safe if child.obsolete?
    end

    [pref_label_html, tooltip]
  end

  def tree_link_to_children(li_id:, child:, ontology_acronym:, lang: )
    "<ul class='ajax'><li id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='/ajax_concepts/#{ontology_acronym}/?conceptid=#{CGI.escape(child.id)}&callback=children&lang=#{lang}'>ajax_class</a></li></ul>"
  end

  def loading_spinner(padding = false, include_text = true)
    loading_text = include_text ? ' loading...' : ''
    if padding
      raw('<div style="padding: 1em;">' + image_tag('spinners/spinner_000000_16px.gif', style: 'vertical-align: text-bottom;') + loading_text + '</div>')
    else
      raw(image_tag('spinners/spinner_000000_16px.gif', style: 'vertical-align: text-bottom;') + loading_text)
    end
  end

  # This gives a very hacky short code to use to uniquely represent a class
  # based on its parent in a tree. Used for unique ids in HTML for the tree view
  def short_uuid
    rand(36**8).to_s(36)
  end

  def render_advanced_picker(custom_ontologies = nil, selected_ontologies = [], align_to_dom_id = nil)
    selected_ontologies ||= []
    init_ontology_picker(custom_ontologies, selected_ontologies)
    render partial: 'shared/ontology_picker_advanced', locals: {
      custom_ontologies: custom_ontologies, selected_ontologies: selected_ontologies, align_to_dom_id: align_to_dom_id
    }
  end

  def init_ontology_picker(ontologies = nil, selected_ontologies = [])
    get_ontologies_data(ontologies)
    get_groups_data
    get_categories_data
    # merge group and category ontologies into a json array
    onts_in_gp_or_cat = @groups_map.values.flatten.to_set
    onts_in_gp_or_cat.merge @categories_map.values.flatten.to_set
    @onts_in_gp_or_cat_for_js = onts_in_gp_or_cat.sort.to_json
  end

  def init_ontology_picker_single
    get_ontologies_data
  end

  def get_ontologies_data(ontologies = nil)
    ontologies ||= LinkedData::Client::Models::Ontology.all(include: 'acronym,name')
    @onts_for_select = []
    @onts_acronym_map = {}
    @onts_uri2acronym_map = {}
    ontologies.each do |ont|
      next if ont.acronym.blank?

      acronym = ont.acronym
      name = ont.name
      abbreviation = acronym.empty? ? '' : "(#{acronym})"
      ont_label = "#{name.strip} #{abbreviation}"
      @onts_for_select << [ont_label, acronym]
      @onts_acronym_map[ont_label] = acronym
      @onts_uri2acronym_map[ont.id] = acronym
    end
    @onts_for_select.sort! { |a, b| a[0].downcase <=> b[0].downcase }
    @onts_for_js = @onts_acronym_map.to_json
  end

  def categories_for_select
    get_ontologies_data
    get_categories_data
    @categories_for_select
  end

  def get_categories_data
    @categories_for_select = []
    @categories_map = {}
    categories = LinkedData::Client::Models::Category.all(include: 'name,ontologies')
    categories.each do |c|
      @categories_for_select << [c.name, c.id]
      @categories_map[c.id] = ontologies_to_acronyms(c.ontologies)
    end
    @categories_for_select.sort! { |a, b| a[0].downcase <=> b[0].downcase }
    @categories_for_js = @categories_map.to_json
  end

  def get_groups_data
    @groups_map = {}
    @groups_for_select = []
    groups = LinkedData::Client::Models::Group.all(include: 'acronym,name,ontologies')
    groups.each do |g|
      next if g.acronym.blank?

      @groups_for_select << [g.name + " (#{g.acronym})", g.acronym]
      @groups_map[g.acronym] = ontologies_to_acronyms(g.ontologies)
    end
    @groups_for_select.sort! { |a, b| a[0].downcase <=> b[0].downcase }
    @groups_for_js = @groups_map.to_json
  end

  def ontologies_to_acronyms(ontologyIDs)
    acronyms = []
    ontologyIDs.each do |id|
      acronyms << @onts_uri2acronym_map[id]
    end
    acronyms.compact
  end

  def at_slice?
    !@subdomain_filter.nil? && !@subdomain_filter[:active].nil? && @subdomain_filter[:active] == true
  end

  def link_last_part(url)
    return '' if url.nil?

    if url.include?('#')
      url.split('#').last
    else
      url.split('/').last
    end
  end

  def subscribe_ontology_button(ontology_id, user = nil)
    user = session[:user] if user.nil?
    if user.nil?
      return sanitize("<a href='/login?redirect=#{request.url}' style='font-size: .9em;' class='subscribe_to_ontology'>Subscribe</a>")
    end

    sub_text = 'Subscribe'
    params = "data-bp_ontology_id='#{ontology_id}' data-bp_is_subbed='false' data-bp_user_id='#{user.id}'"
    begin
      # Try to create an intelligent subscribe button.
      if ontology_id.start_with? 'http'
        ont = LinkedData::Client::Models::Ontology.find(ontology_id)
      else
        ont = LinkedData::Client::Models::Ontology.find_by_acronym(ontology_id).first
      end
      subscribed = subscribed_to_ontology?(ont.acronym, user)
      sub_text = subscribed ? 'Unsubscribe' : 'Subscribe'
      params = "data-bp_ontology_id='#{ont.acronym}' data-bp_is_subbed='#{subscribed}' data-bp_user_id='#{user.id}'"
    rescue
      # pass, fallback init done above begin block to scope parameters beyond the begin/rescue block
    end
    spinner = '<span class="subscribe_spinner" style="display: none;">' + image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + '</span>'
    error = "<span style='color: red;' class='subscribe_error'></span>"
    "<a href='javascript:void(0);' class='subscribe_to_ontology link_button' #{params}>#{sub_text}</a> #{spinner} #{error}"
  end

  def subscribed_to_ontology?(ontology_acronym, user)
    return false if user.subscription.blank?

    # In some cases this method is called with user objects that don't have the :ontology attribute loaded on
    # the associated subscription objects. Calling find is the only way (?) to ensure that we get a user where the
    # :ontology attribute is loaded for all subscriptions.
    ontology_attributes_missing = user.subscription.any? { |sub| sub[:ontology].nil? }
    user = LinkedData::Client::Models::User.find(user.id) if ontology_attributes_missing

    sub = user.subscription.select { |sub| sub[:ontology].split('/').last.eql? ontology_acronym }
    sub.length.positive? ? 'true' : 'false'
  end

  # http://stackoverflow.com/questions/1293573/rails-smart-text-truncation
  def smart_truncate(s, opts = {})
    opts = { words: 20 }.merge(opts)
    if opts[:sentences]
      return s.split(/\.(\s|$)+/)[0, opts[:sentences]].map { |s| s.strip }.join('. ') + '. ...'
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
    d = DateTime.xmlschema(xml_date_time_str).to_date
    # Return conventional US date format:
    sprintf("%02d/%02d/%4d", d.month, d.day, d.year)
  end

  def flash_class(level)
    bootstrap_alert_class = {
      'notice' => 'alert-info',
      'success' => 'alert-success',
      'error' => 'alert-danger',
      'alert' => 'alert-danger',
      'warning' => 'alert-warning'
    }
    bootstrap_alert_class[level]
  end

  # NOTE: The following 4 methods (bp_ont_link, bp_class_link, get_link_for_cls_ajax, get_link_for_ont_ajax) are
  # the Ruby equivalent of JS code in bp_ajax_controller.js and are used in the concepts/_details partial.
  def bp_ont_link(ont_acronym)
    "/ontologies/#{ont_acronym}"
  end


  def bp_class_link(cls_id, ont_acronym)
    "#{bp_ont_link(ont_acronym)}?p=classes&conceptid=#{escape(cls_id)}&language=#{request_lang}"
  end

  def label_ajax_data_h(cls_id, ont_acronym, ajax_uri, cls_url)
    { data:
        {
          'label-ajax-cls-id-value': cls_id,
          'label-ajax-ontology-acronym-value': ont_acronym,
          'label-ajax-ajax-url-value': ajax_uri,
          'label-ajax-cls-id-url-value': cls_url
        }
    }
  end

  def label_ajax_data(cls_id, ont_acronym, ajax_uri, cls_url)
    label_ajax_data_h(cls_id, ont_acronym, ajax_uri, cls_url)
  end

  def label_ajax_link(link, cls_id, ont_acronym, ajax_uri, cls_url, target = nil)
    data = label_ajax_data(cls_id, ont_acronym, ajax_uri, cls_url)
    options = {  'data-controller': 'label-ajax' }.merge(data)
    options = options.merge({ target: target }) if target
    content_tag(:span, class: 'mx-1') do
      render ChipButtonComponent.new(url: link, text: cls_id, type: 'clickable', **options)
    end
  end

  def get_link_for_cls_ajax(cls_id, ont_acronym, target = nil, style_as_badge = false)
    if cls_id.start_with?('http://') || cls_id.start_with?('https://')
      link = bp_class_link(cls_id, ont_acronym)
      ajax_url = "/ajax/classes/label?language=#{request_lang}"
      cls_url = "/ontologies/#{ont_acronym}?p=classes&conceptid=#{CGI.escape(cls_id)}"
      label_ajax_link(link, cls_id, ont_acronym, ajax_url, cls_url, target)
    else
      if style_as_badge
        render ChipButtonComponent.new(text: cls_id)
      else
        content_tag(:div, cls_id)
      end
    end
  end

  def get_link_for_ont_ajax(ont_acronym)
    # Ajax call will replace the acronym with an ontology name (triggered by class='ont4ajax')
    href_ont = " href='#{bp_ont_link(ont_acronym)}' "
    data_ont = " data-ont='#{ont_acronym}' "
    "<a class='ont4ajax' #{data_ont} #{href_ont}>#{ont_acronym}</a>"
  end

  ###END ruby equivalent of JS code in bp_ajax_controller.
  def ontology_viewer_page_name(ontology_name, concept_name_title, page)
    "#{ontology_name} - #{concept_name_title} - #{page.capitalize}"
  end

  def analytics_consent?
    cookies[:allow_cookies].present? && cookies[:allow_cookies] == 'true'
  end

  # Google Search Console (Webmaster Tools) site-verification meta tag.
  # Configurable per environment via settings.yml (google_site_verification)
  # instead of being hard-coded; omitted entirely on the appliance and when
  # no token is configured. (closes ncbo#90)
  def google_site_verification_meta_tag
    return if Rails.env.appliance?

    token = Rails.configuration.settings.dig(:google_site_verification)
    return if token.blank?

    tag.meta(name: 'google-site-verification', content: token)
  end
end
