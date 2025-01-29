require 'uri'
require 'cgi'
require 'digest/sha1'

module ApplicationHelper
  def get_apikey
    unless session[:user].nil?
      session[:user].apikey
    else
      LinkedData::Client.settings.apikey
    end
  end

  def escape(url)
    CGI.escape(url) if url
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
    page_name = ontology_viewer_page_name(ontology_acronym, child.prefLabel, 'Classes')
    open = child.expanded? ? "class='open'" : ''
    href = ontology_acronym.blank? ? '#' :  "/ontologies/#{child.explore.ontology.acronym}/concepts/?id=#{CGI.escape(child.id)}&lang=#{lang}"
    "<li #{open} id='#{li_id}'><a id='#{CGI.escape(child.id)}' data-bp-ont-page-name='#{page_name}' data-turbo=true data-turbo-frame='concept_show' href='#{href}' #{active_style}> #{child.prefLabel({ use_html: true })}</a>"
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
    ontology_path(id: ont_acronym, p: 'classes', conceptid: cls_id)
  end

  def get_link_for_cls_ajax(cls_id, ont_acronym, target = nil)
    # NOTE: bp_ajax_controller.ajax_process_cls will try to resolve class labels.
    # Uses 'http' as a more generic attempt to resolve class labels than .include? ont_acronym; the
    # bp_ajax_controller.ajax_process_cls will try to resolve class labels and
    # otherwise remove the UNIQUE_SPLIT_STR and the ont_acronym.
    target = target.nil? ? '' : " target='#{target}' "

    if cls_id.start_with?('http://', 'https://')
      href_cls = " href='#{bp_class_link(cls_id, ont_acronym)}' "
      data_cls = " data-cls='#{cls_id}' "
      data_ont = " data-ont='#{ont_acronym}' "
      "<a class='cls4ajax' #{data_ont} #{data_cls} #{href_cls} #{target}>#{cls_id}</a>"
    else
      content_tag(:div, cls_id)
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

end
