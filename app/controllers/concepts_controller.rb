# frozen_string_literal: true

class ConceptsController < ApplicationController
  include MappingsHelper
  before_action :redirect_new_api, except: [:show, :biomixer]

  layout 'ontology'

  def show_concept
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => "Error: You must provide a valid concept id"
      return
    end

    # Note that find_by_acronym includes views by default
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    @ob_instructions = helpers.ontolobridge_instructions_template(@ontology)
    @concept = @ontology.explore.single_class({full: true}, params[:id])

    not_found if @concept.nil?
    gather_details
    render :partial => 'show'
  end

  def show
    params[:id] = params[:id] || params[:conceptid]

    if params[:id].blank?
      render text: 'Error: You must provide a valid concept id'
      return
    end

    # find_by_acronym includes views by default
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    @ob_instructions = helpers.ontolobridge_instructions_template(@ontology)

    if request.xhr?
      display = params[:callback].eql?('load') ? { full: true } : { display: 'prefLabel' }
      @concept = @ontology.explore.single_class(display, params[:id])
      not_found if @concept.nil?
      show_ajax_request
    else
      render plain: 'Non-AJAX requests are not accepted at this URL', status: :forbidden
    end
  end

  def show_label
    @ontology = LinkedData::Client::Models::Ontology.find(params[:ontology])
    @ontology ||= LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found unless @ontology
    # Retrieve a class prefLabel or return the class ID (URI)
    # - mappings may contain class URIs that are not in bioportal (e.g. obo-xrefs)
    cls = @ontology.explore.single_class(params[:concept])
    # TODO: log any cls.errors
    # TODO: NCBO-402 might be implemented here, but it throws off a lot of ajax result rendering.
    # cls_label = cls.prefLabel({:use_html => true}) || cls_id
    cls_label = cls.prefLabel || params[:concept]
    render plain: cls_label
  end

  def show_definition
    @ontology = LinkedData::Client::Models::Ontology.find(params[:ontology])
    cls = @ontology.explore.single_class(params[:concept])
    render text: cls.definition
  end

  def show_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    if @ontology.nil?
      not_found
    else
      get_class(params)
      render partial: 'ontologies/treeview'
    end
  end

  def property_tree
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?
    @root = @ontology.property_tree
    render json: LinkedData::Client::Models::Property.properties_to_hash(@root.children)
  end

  def details
    not_found if params[:conceptid].blank?

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, CGI.unescape(params[:conceptid]))
    not_found if @concept.nil?

    if params[:styled].eql?('true')
      render partial: 'details', layout: 'partial'
    else
      render partial: 'details'
    end
  end

  def biomixer
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?

    @concept = @ontology.explore.single_class({ full: true }, params[:conceptid])
    not_found if @concept.nil?

    @immediate_load = true

    render partial: 'biomixer', layout: false
  end

  def redirect_new_api
    return unless params[:ontology].to_i.positive?

    params_cleanup_new_api
    redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: %w[controller action])}",
                status: :moved_permanently
  end

  private

  # Load data for a concept or retrieve a concept's children, depending on the value of the :callback parameter.
  # Children are retrieved for drawing ontology class trees.
  def show_ajax_request
    case params[:callback]
    when 'load'
      gather_details
      render partial: 'load'
    when 'children'
      @children = @concept.explore.children(pagesize: 750).collection || []
      @children.sort! { |x, y| (x.prefLabel || '').downcase <=> (y.prefLabel || '').downcase }
      render partial: 'child_nodes'
    end
  end

  def gather_details
    @mappings = get_concept_mappings(@concept)
    @notes = @concept.explore.notes
    @delete_mapping_permission = check_delete_mapping_permission(@mappings)
    update_tab(@ontology, @concept.id)
  end
end
