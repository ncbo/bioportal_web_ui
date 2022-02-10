# Methods added to this helper will be available to all templates in the application.

require 'uri'
require 'cgi'
require 'digest/sha1'
require 'pry' # used in a rescue

module ApplicationHelper

  def get_apikey
    unless session[:user].nil?
      return session[:user].apikey
    else
      return LinkedData::Client.settings.apikey
    end
  end

  def isOwner?(id)
    unless session[:user].nil?
      if session[:user].admin?
        return true
      elsif session[:user].id.eql?(id)
        return true
      else
        return false
      end
    end
  end

  def encode_param(string)
    return URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def escape(string)
    CGI.escape(string)
  end

  def clean(string)
    string = string.gsub("\"",'\'')
    return string.gsub("\n",'')
  end

  def clean_id(string)
    new_string = string.gsub(":","").gsub("-","_").gsub(".","_")
    return new_string
  end

  def to_param(string)
     "#{encode_param(string.gsub(" ","_"))}"
  end

  def get_username(user_id)
    user = LinkedData::Client::Models::User.find(user_id)
    username = user.nil? ? user_id : user.username
    username
  end

  def current_user_admin?
    session[:user] && session[:user].admin?
  end

  def remove_owl_notation(string)
    # TODO_REV: No OWL notation, but should we modify the IRI?
    return string

    unless string.nil?
      strings = string.split(":")
      if strings.size<2
        #return string.titleize
        return string
      else
        #return strings[1].titleize
        return strings[1]
      end
    end
  end

  def draw_note_tree(notes,key)
    output = ""
    draw_note_tree_leaves(notes,0,output,key)
    return output
  end

  def draw_note_tree_leaves(notes,level,output,key)
    for note in notes
      name="Anonymous"
      unless note.user.nil?
        name=note.user.username
      end
      headertext=""
      notetext=""
      if note.note_type.eql?(5)
        headertext<< "<div class=\"header\" onclick=\"toggleHide('note_body#{note.id}','');compare('#{note.id}')\">"
        notetext << " <input type=\"hidden\" id=\"note_value#{note.id}\" value=\"#{note.comment}\">
                  <span class=\"message\" id=\"note_text#{note.id}\">#{note.comment}</span>"
      else
        headertext<< "<div onclick=\"toggleHide('note_body#{note.id}','')\">"

        notetext<< "<span class=\"message\" id=\"note_text#{note.id}\">#{simple_format(note.comment)}</span>"
      end


      output << "
        <div style=\"clear:both;margin-left:#{level*20}px;\">
        <div  style=\"float:left;width:100%\">
          #{headertext}
              <div>
                <span class=\"sender\" style=\"float:right\">#{name} at #{note.created_at.strftime('%m/%d/%y %H:%M')}</span>
                <div class=\"header\"><span class=\"notetype\">#{note.type_label.titleize}:</span> #{note.subject}</div>
                              <div style=\"clear:both\"></div>
              </div>

          </div>

          <div name=\"hiddenNote\" id=\"note_body#{note.id}\" >
          <div class=\"messages\">
            <div>
              <div>
               #{notetext}"
      if session[:user].nil?
        output << "<div id=\"insert\"><a href=\"\/login?redirect=/visualize/#{@ontology.to_param}/?conceptid=#{@concept.id}#notes\">Reply</a></div>"
      else
        if @modal
          output << "<div id=\"insert\"><a href=\"#\"  onclick =\"document.getElementById('m_noteParent').value='#{note.id}';document.getElementById('m_note_subject#{key}').value='RE:#{note.subject}';jQuery('#modal_form').html(jQuery('#modal_comment').html());return false;\">Reply</a></div>"
        else
          output << "<div id=\"insert\"><a href=\"#TB_inline?height=400&width=600&inlineId=commentForm\" class=\"thickbox\" onclick =\"document.getElementById('noteParent').value='#{note.id}';document.getElementById('note_subject#{key}').value='RE:#{note.subject}';\">Reply</a></div>"
        end
      end
      output << "</div>
            </div>
          </div>

          </div>
        </div>
        </div>"
      if(!note.children.nil? && note.children.size>0)
        draw_note_tree_leaves(note.children,level+1,output,key)
      end
    end
  end

  def draw_tree(root, id = nil, type = "Menu")
    if id.nil?
      id = root.children.first.id
    end
    # TODO: handle tree view for obsolete classes, e.g. 'http://purl.obolibrary.org/obo/GO_0030400'
    raw build_tree(root, "", id)  # returns a string, representing nested list items
  end

  def build_tree(node, string, id)
    if node.children.nil? || node.children.length < 1
      return string # unchanged
    end
    node.children.sort! {|a,b| (a.prefLabel || a.id).downcase <=> (b.prefLabel || b.id).downcase}
    for child in node.children
      if child.id.eql?(id)
        active_style="class='active'"
      else
        active_style = ""
      end
      if child.expanded?
        open = "class='open'"
      else
        open = ""
      end

      # This fake root will be present at the root of "flat" ontologies, we need to keep the id intact
      li_id = child.id.eql?("bp_fake_root") ? "bp_fake_root" : short_uuid

      if child.id.eql?("bp_fake_root")
        string << "<li class='active' id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='#' #{active_style}>#{child.prefLabel}</a></li>"
      else
        icons = child.relation_icon(node)
        string << "<li #{open} id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='/ontologies/#{child.explore.ontology.acronym}/?p=classes&conceptid=#{CGI.escape(child.id)}' #{active_style}> #{child.prefLabel({use_html: true})}</a> #{icons}"
        if child.hasChildren && !child.expanded?
          string << "<ul class='ajax'><li id='#{li_id}'><a id='#{CGI.escape(child.id)}' href='/ajax_concepts/#{child.explore.ontology.acronym}/?conceptid=#{CGI.escape(child.id)}&callback=children'>ajax_class</a></li></ul>"
        elsif child.expanded?
          string << "<ul>"
          build_tree(child, string, id)
          string << "</ul>"
        end
        string << "</li>"
      end
    end

    string
  end

  def loading_spinner(padding = false, include_text = true)
    loading_text = include_text ? " loading..." : ""
    if padding
      raw('<div style="padding: 1em;">' + image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + loading_text + '</div>')
    else
      raw(image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + loading_text)
    end
  end

  # This gives a very hacky short code to use to uniquely represent a class
  # based on its parent in a tree. Used for unique ids in HTML for the tree view
  def short_uuid
    rand(36**8).to_s(36)
  end

  def help_icon(link, html_attribs = {})
    html_attribs["title"] ||= "Help"
    attribs = []
    html_attribs.each {|k,v| attribs << "#{k.to_s}='#{v}'"}
    return <<-BLOCK
          <a target="_blank" href='#{link}' class='pop_window help_link' #{attribs.join(" ")}>
            <span class="pop_window ui-icon ui-icon-help"></span>
          </a>
    BLOCK
  end

  def anonymous_user
    #
    # TODO: Fix and failures from removing 'DataAccess' call here.
    #
    #user = DataAccess.getUser($ANONYMOUS_USER)
    user ||= User.new({"id" => 0})
  end

  def render_advanced_picker(custom_ontologies = nil, selected_ontologies = [], align_to_dom_id = nil)
    selected_ontologies ||= []
    init_ontology_picker(custom_ontologies, selected_ontologies)
    render :partial => "shared/ontology_picker_advanced", :locals => {
        :custom_ontologies => custom_ontologies, :selected_ontologies => selected_ontologies, :align_to_dom_id => align_to_dom_id
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
    ontologies ||= LinkedData::Client::Models::Ontology.all(include: "acronym,name")
    @onts_for_select = []
    @onts_acronym_map = {}
    @onts_uri2acronym_map = {}
    ontologies.each do |ont|
      # TODO: ontologies parameter may be a list of ontology models (not ontology submission models):
      # ont.acronym instead of ont.ontology.acronym
      # ont.name instead of ont.ontology.name
      # ont.id instead of ont.ontology.id
      # TODO: annotator passes in 'custom_ontologies' to the ontologies parameter.
      next if ( ont.acronym.nil? or ont.acronym.empty? )
      acronym = ont.acronym
      name = ont.name
      #id = ont.id # ontology URI
      abbreviation = acronym.empty? ? "" : "(#{acronym})"
      ont_label = "#{name.strip} #{abbreviation}"
      #@onts_for_select << [ont_label, id]  # using the URI crashes the UI checkbox selection behavior.
      @onts_for_select << [ont_label, acronym]
      @onts_acronym_map[ont_label] = acronym
      @onts_uri2acronym_map[ont.id] = acronym  # required in ontologies_to_acronyms
    end
    @onts_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    @onts_for_js = @onts_acronym_map.to_json
  end

  def categories_for_select
    # This method is called in the search index page.
    get_ontologies_data
    get_categories_data
    return @categories_for_select
  end

  def get_categories_data
    @categories_for_select = []
    @categories_map = {}
    categories = LinkedData::Client::Models::Category.all(include: "name,ontologies")
    categories.each do |c|
      @categories_for_select << [ c.name, c.id ]
      @categories_map[c.id] = ontologies_to_acronyms(c.ontologies) # c.ontologies is a list of URIs
    end
    @categories_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    @categories_for_js = @categories_map.to_json
  end

  def get_groups_data
    @groups_map = {}
    @groups_for_select = []
    groups = LinkedData::Client::Models::Group.all(include: "acronym,name,ontologies")
    groups.each do |g|
      next if ( g.acronym.nil? or g.acronym.empty? )
      @groups_for_select << [ g.name + " (#{g.acronym})", g.acronym ]
      @groups_map[g.acronym] = ontologies_to_acronyms(g.ontologies) # g.ontologies is a list of URIs
    end
    @groups_for_select.sort! { |a,b| a[0].downcase <=> b[0].downcase }
    @groups_for_js = @groups_map.to_json
  end

  def ontologies_to_acronyms(ontologyIDs)
    acronyms = []
    ontologyIDs.each do |id|
      acronyms << @onts_uri2acronym_map[id]  # hash generated in get_ontologies_data
    end
    return acronyms.compact # remove nil values from any failures to convert ontology URI to acronym
  end

  def at_slice?
    !@subdomain_filter.nil? && !@subdomain_filter[:active].nil? && @subdomain_filter[:active] == true
  end

  def truncate_with_more(text, options = {})
    length ||= options[:length] ||= 30
    trailing_text ||= options[:trailing_text] ||= " ... "
    link_more ||= options[:link_more] ||= "[more]"
    link_less ||= options[:link_less] ||= "[less]"
    more_text = " <a href='javascript:void(0);' class='truncated_more'>#{link_more}</a></span><span class='truncated_less'>#{text} <a href='javascript:void(0);' class='truncated_less'>#{link_less}</a></span>"
    more = text.length > length ? more_text : "</span>"
    output = "<span class='more_less_container'><span class='truncated_more'>#{truncate(text, :length => length, :omission => trailing_text)}" + more + "</span>"
  end

  def subscribe_ontology_button(ontology_id, user = nil)
    user = session[:user] if user.nil?
    if user.nil?
      # subscribe button must redirect to login
      return sanitize("<a href='/login?redirect=#{request.url}' style='font-size: .9em;' class='subscribe_to_ontology'>Subscribe</a>")
    end
    # Init subscribe button parameters.
    sub_text = "Subscribe"
    params = "data-bp_ontology_id='#{ontology_id}' data-bp_is_subbed='false' data-bp_user_id='#{user.id}'"
    begin
      # Try to create an intelligent subscribe button.
      if ontology_id.start_with? 'http'
        ont = LinkedData::Client::Models::Ontology.find(ontology_id)
      else
        ont = LinkedData::Client::Models::Ontology.find_by_acronym(ontology_id).first
      end
      subscribed = subscribed_to_ontology?(ont.acronym, user)  # application_helper
      sub_text = subscribed ? "Unsubscribe" : "Subscribe"
      params = "data-bp_ontology_id='#{ont.acronym}' data-bp_is_subbed='#{subscribed}' data-bp_user_id='#{user.id}'"
    rescue
      # pass, fallback init done above begin block to scope parameters beyond the begin/rescue block
    end
    # TODO: modify/copy CSS for notes_sub_error => subscribe_error
    # TODO: modify/copy CSS for subscribe_to_notes => subscribe_to_ontology
    spinner = '<span class="subscribe_spinner" style="display: none;">' + image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + '</span>'
    error = "<span style='color: red;' class='subscribe_error'></span>"
    return "<a href='javascript:void(0);' class='subscribe_to_ontology link_button' #{params}>#{sub_text}</a> #{spinner} #{error}"
  end

  def subscribed_to_ontology?(ontology_acronym, user)
    user.bring(:subscription) if user.subscription.nil?
    # user.subscription is an array of subscriptions like {ontology: ontology_id, notification_type: "NOTES"}
    return false if user.subscription.nil? or user.subscription.empty?
    user.subscription.each do |sub|
      #sub = {ontology: ontology_acronym, notification_type: "NOTES"}
      sub_ont_acronym = sub[:ontology].split('/').last # make sure we get the acronym, even if it's a full URI
      return true if sub_ont_acronym == ontology_acronym
    end
    return false
  end

  def ontolobridge_instructions_template(ontology)
    ont_data = Ontology.find_by(acronym: ontology.acronym)
    ont_data.nil? || ont_data.new_term_instructions.empty? ? t('concepts.request_term.new_term_instructions') : ont_data.new_term_instructions
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

  def flash_class(level)
    case level
    when "notice" 
      "alert alert-info"
    when "success" 
      "alert alert-success"
    when "error"
      "alert alert-danger"
    when "alert" 
      "alert alert-error"
    end
  end

  ###BEGIN ruby equivalent of JS code in bp_ajax_controller.
  ###Note: this code is used in concepts/_details partial.
  def bp_ont_link(ont_acronym)
    return "/ontologies/#{ont_acronym}"
  end
  def bp_class_link(cls_id, ont_acronym)
    return "#{bp_ont_link(ont_acronym)}?p=classes&conceptid=#{URI.escape(cls_id, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
  end
  def get_link_for_cls_ajax(cls_id, ont_acronym, target=nil)
    # Note: bp_ajax_controller.ajax_process_cls will try to resolve class labels.
    # Uses 'http' as a more generic attempt to resolve class labels than .include? ont_acronym; the
    # bp_ajax_controller.ajax_process_cls will try to resolve class labels and
    # otherwise remove the UNIQUE_SPLIT_STR and the ont_acronym.
    if target.nil?
      target = ""
    else
      target = " target='#{target}' "
    end
    if cls_id.start_with? 'http://'
      href_cls = " href='#{bp_class_link(cls_id, ont_acronym)}' "
      data_cls = " data-cls='#{cls_id}' "
      data_ont = " data-ont='#{ont_acronym}' "
      return "<a class='cls4ajax' #{data_ont} #{data_cls} #{href_cls} #{target}>#{cls_id}</a>"
    else
      return auto_link(cls_id, :all, :target => '_blank')
    end
  end
  def get_link_for_ont_ajax(ont_acronym)
    # ajax call will replace the acronym with an ontology name (triggered by class='ont4ajax')
    href_ont = " href='#{bp_ont_link(ont_acronym)}' "
    data_ont = " data-ont='#{ont_acronym}' "
    return "<a class='ont4ajax' #{data_ont} #{href_ont}>#{ont_acronym}</a>"
  end
  ###END ruby equivalent of JS code in bp_ajax_controller.


  def uri?(url)
    url =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/
  end

  def extract_label_from(uri)
    label = uri.to_s
    index = label.index('#')
    if !index.nil?
      label = label[(index + 1) , uri.length-1]
    else
      index = label.rindex('/')
      label = label[(index + 1), uri.length-1]  if index > -1
    end
    label
  end

end
