require 'cgi'

class ConceptsController < ApplicationController
  include MappingsHelper
  include ConceptsHelper
  include TurboHelper
  include TermsReuses

  layout 'ontology'

  def show
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => t('concepts.error_valid_concept')
      return
    end

    # Note that find_by_acronym includes views by default
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    redirect_to(ontology_path(id: params[:ontology], p: 'classes', conceptid: params[:id], lang: request_lang)) and return unless turbo_frame_request?

    @submission = get_ontology_submission_ready(@ontology)
    @concept = @ontology.explore.single_class({ full: true, language: request_lang }, params[:id])

    concept_not_found(params[:id]) if @concept.nil?
    @current_purl = @concept.purl if Rails.configuration.settings.purl[:enabled]
    @notes = @concept.explore.notes
    render partial: 'show'
  end

  def index
    # Handle multiple methods of passing concept ids
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => t('concepts.error_valid_concept')
      return
    end

    @submission = LinkedData::Client::Models::Ontology.explore(params[:ontology])
                                                      .latest_submission
                                                      .get(include: 'uriRegexPattern,preferredNamespaceUri')
    @schemes = params[:concept_schemes].split(',')

    @concept = LinkedData::Client::Models::Class.new(values: { id: params[:id] })

    @concept.children = LinkedData::Client::Models::Ontology.explore(params[:ontology])
                                                            .classes(params[:id])
                                                            .children
                                                            .get(pagesize: 750, concept_schemes: Array(@schemes).join(','), language: request_lang, display: 'prefLabel,obsolete,hasChildren').collection || []
    render turbo_stream: [
      replace(helpers.child_id(@concept) + '_open_link') { TreeLinkComponent.tree_close_icon },
      replace(helpers.child_id(@concept) + '_childs') do
        helpers.concepts_tree_component(@concept, @concept, params[:ontology], Array(@schemes), request_lang, sub_tree: true, submission: @submission)
      end
    ]
  end

  def show_label
    cls_id = params[:concept] || params[:id]
    ont_id = params[:ontology]
    pref_label = begin
                   concept_label(ont_id, cls_id)
                 rescue
                   cls_id
                 end
    cls = @ontology.explore&.single_class({ language: request_lang, include: 'prefLabel' }, cls_id)
    label = helpers.main_language_label(pref_label)
    acronym = ont_id.split("/").last
    link = concept_path(cls_id, acronym, request_lang)

    render(inline: helpers.ajax_link_chip(cls_id, label, link, external: cls.nil? || cls.errors), layout: nil)
  end

  def show_definition
    @ontology = LinkedData::Client::Models::Ontology.find(params[:ontology])
    cls = @ontology.explore.single_class(params[:concept])

    render :text => cls.definition
  end

  def show_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    @submission = @ontology.explore.latest_submission(include: 'uriRegexPattern,preferredNamespaceUri')
    if @ontology.nil? || @ontology.errors
      ontology_not_found(params[:ontology])
    else
      get_class(params, @submission)

      not_found(t('concepts.missing_roots')) if @root.nil?

      render inline: helpers.concepts_tree_component(@root, @concept,
                                                     @ontology.acronym, Array(params[:concept_schemes]&.split(',')), request_lang,
                                                     id: 'concepts_tree_view', auto_click: params[:auto_click] || true)
    end
  end

  def show_date_sorted_list
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    if @ontology.nil?
      ontology_not_found(params[:ontology])
    else
      @submission = @ontology.explore.latest_submission(include: 'uriRegexPattern,preferredNamespaceUri')
      page = params[:page]
      @last_date = params[:last_date]
      auto_click = page.to_s.eql?('1')
      params = {
        page: page,
        sortby: 'modified,created',
        order: 'desc,desc',
        display: 'prefLabel,modified,created',
        language: request_lang
      }
      if @last_date
        params.merge!(last_date: @last_date)
        @last_date = Date.parse(@last_date)
      end

      @page = @ontology.explore.classes(params)
      @concepts = filter_concept_with_no_date(@page.collection)
      @concepts_year_month = concepts_to_years_months(@concepts)

      render partial: 'concepts/date_sorted_list', locals: { auto_click: auto_click }
    end

  end

  def property_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?
    @root = @ontology.property_tree
    render json: LinkedData::Client::Models::Property.properties_to_hash(@root.children)
  end

  # Renders a details pane for a given ontology/concept
  def details
    concept_not_found(params[:conceptid]) if params[:conceptid].blank?

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, CGI.unescape(params[:conceptid]))
    concept_not_found(CGI.unescape(params[:conceptid])) if @concept.nil? || @concept.errors
    @container_id = params[:modal] ? 'application_modal_content' : 'concept_details'

    render :partial => "details"
  end

  def biomixer
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, params[:conceptid])
    concept_not_found(params[:conceptid]) if @concept.nil?

    render partial: "biomixer", layout: false
  end

  private

  def filter_concept_with_no_date(concepts)
    concepts.filter { |c| !concept_date(c).nil? }
  end

  def concepts_to_years_months(concepts)
    return {} if concepts.nil? || concepts.empty?

    concepts.group_by { |c| concept_date(c).year }
            .transform_values do |items|
      items.group_by { |c| concept_date(c).strftime('%B') }
    end
  end
end
