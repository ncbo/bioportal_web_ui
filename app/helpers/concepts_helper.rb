# frozen_string_literal: true
module ConceptsHelper
  include TermsReuses, UrlsHelper

  def concept_path(id, ontology_id, language)
    "/ontologies/#{ontology_id}?p=classes&conceptid=#{escape(id)}&language=#{language}"
  end

  def concept_link(acronym, child, language)
    child.id.eql?('bp_fake_root') ? '#' : "/ontologies/#{acronym}/concepts/show?id=#{CGI.escape(child.id)}&language=#{language}"
  end

  def concept_children_link(acronym, child, language, concept_schemes)
    "/ontologies/#{acronym}/concepts?conceptid=#{CGI.escape(child.id)}&concept_schemes=#{concept_schemes.join(',')}&language=#{language}"
  end

  def concept_tree_data(acronym, child, language, concept_schemes)
    href = concept_link(acronym, child, language)
    children_link = concept_children_link(acronym, child, language, concept_schemes)
    data = {
      conceptid: child.id,
      'active-collections-value': child.isInActiveCollection || [],
      'collections-value': child.memberOf || [],
      'skos-collection-colors-target': 'collection',
    }
    [children_link, data, href]
  end

  def concepts_tree_component(root, selected_concept, acronym, concept_schemes, language, sub_tree: false, id: nil,
                              auto_click: false, submission: @submission)
    tree_component(root, selected_concept, target_frame: 'concept_show', sub_tree: sub_tree, id: id,
                                           auto_click: auto_click, submission: submission) do |child|
      concept_tree_data(acronym, child, language, concept_schemes)
    end
  end

  # True when the ontology declares its own display roots via IAO:0000700
  # (submission.hasOntologyRootTerm). Used to show the "Show full hierarchy" tree
  # toggle only when it would do something. Requires the submission to have been
  # fetched with hasOntologyRootTerm included (see show_tree / get_class).
  #
  # SKOS vocabularies declare their tops with skos:hasTopConcept, not IAO:0000700,
  # and the tree already roots them there, so the declared-roots toggle is excluded
  # for SKOS even if an IAO:0000700 assertion happens to be present.
  def ontology_declares_roots?(submission = @submission)
    return false if submission&.hasOntologyLanguage === 'SKOS'

    Array(submission&.hasOntologyRootTerm).map(&:to_s).any?(&:present?)
  end

  def exclude_relation?(relation_to_check, ontology = nil)
    excluded_relations = %w[type rdf:type [R] SuperClass InstanceCount]

    # Show or hide property based on the property and ontology settings
    if ontology
      # TODO_REV: Handle obsolete classes
      # Hide owl:deprecated if a user has set class or property based obsolete checking
      # if !ontology.obsoleteParent.nil? && relation_to_check.include?("owl:deprecated") ||
      #    !ontology.obsoleteProperty.nil? && relation_to_check.include?("owl:deprecated")
      #   return true
      # end
    end
    excluded_relations.each do |relation|
      return true if relation_to_check.include?(relation)
    end
    false
  end

  def get_concept_id(params, concept, root)
    return nil if concept.nil?

    if concept_id_param_exist?(params)
      concept.nil? ? '' : concept.id
    elsif root && !root.children.first.nil?
      root.children.first.id
    end
  end

  def sub_menu_active?(section)
    params["sub_menu"]&.eql? section
  end

  def sub_menu_active_class(section)
    "active show" if sub_menu_active?(section)
  end

  def default_sub_menu?
    !sub_menu_active?('list') && !sub_menu_active?('date')
  end

  def default_sub_menu_class
    "active show" if default_sub_menu?
  end

  def concept_label(ont_id, cls_id)
    @ontology = LinkedData::Client::Models::Ontology.find(ont_id)
    @ontology ||= LinkedData::Client::Models::Ontology.find_by_acronym(ont_id).first
    ontology_not_found(ont_id) if @ontology.nil? || @ontology.errors
    cls = @ontology.explore.single_class({language: request_lang, include: 'prefLabel'}, cls_id)
    cls&.prefLabel || cls_id
  end

  def concept_id_param_exist?(params)
    !(params[:conceptid].nil? || params[:conceptid].empty? || params[:conceptid].eql?("root") ||
      params[:conceptid].eql?("bp_fake_root"))
  end

  def concept_date(concept)
    date = concept.modified || concept.created
    Date.parse(date) if date
  end

  def sorted_by_date_url(page = 1, last_concept = nil)
    out = "/ajax/classes/date_sorted_list?ontology=#{@ontology.acronym}&page=#{page}&language=#{request_lang}"
    out += "&last_date=#{concept_date(last_concept)}" if last_concept
    out
  end

  def same_period?(year, month, date)
    return false if date.nil?
    date = Date.parse(date.to_s)
    year.eql?(date.year) && month.eql?(date.strftime('%B'))
  end

  def concepts_li_list(concepts, auto_click: false, selected_id: nil, submission: nil)
    out = ''
    concepts.each do |concept|
      children_link, data, href = concept_tree_data(@ontology.acronym, concept, request_lang, [])

      out += render TreeLinkComponent.new(child: concept, href: href,
                                          children_href: '#', selected: concept.id.eql?(selected_id) && auto_click,
                                          target_frame: 'concept_show', data: data, is_reused: concept_reused?(submission: submission, concept_id: concept.id))
    end
    out
  end

  def render_concepts_by_dates(auto_click: false, submission: @submission)
    return if @concepts_year_month.empty?

    first_year, first_month_concepts = @concepts_year_month.shift
    first_month, first_concepts = first_month_concepts.shift
    out = ''
    if same_period?(first_year, first_month, @last_date)
      out += "<ul>#{concepts_li_list(first_concepts, auto_click: auto_click, submission: submission)}</ul>"
    else
      tmp = {}
      tmp[first_month] = first_concepts
      first_month_concepts = tmp.merge(first_month_concepts)
    end
    tmp = {}
    tmp[first_year] = first_month_concepts
    @concepts_year_month = tmp.merge(@concepts_year_month)
    selected_id = @concepts.first.id if @page.page.eql?(1)
    @concepts_year_month.each do |year, month_concepts|
      month_concepts.each do |month, concepts|
        out += "<ul> #{month + ' ' + year.to_s}"
        out += concepts_li_list(concepts, auto_click: auto_click, selected_id: selected_id,
                                          submission: submission)
        out += '</ul>'
      end
    end
    raw out
  end

  def concept_list_url(page = 1, collection_id, acronym)
    "/ajax/classes/list?ontology_id=#{acronym}&collectionid=#{collection_id}&page=#{page}"
  end

  private

  def concept_redirect_path
    ontology_path(@ontology.acronym, p: 'classes', conceptid: @concept.id)
  end
end
