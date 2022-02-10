require 'cgi'

class ConceptsController < ApplicationController
  include MappingsHelper
  include ConceptsHelper
  layout 'ontology'

  def show
    # Handle multiple methods of passing concept ids
    params[:id] = params[:id] ? params[:id] : params[:conceptid]

    if params[:id].nil? || params[:id].empty?
      render :text => "Error: You must provide a valid concept id"
      return
    end

    # Note that find_by_acronym includes views by default
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    @ob_instructions = helpers.ontolobridge_instructions_template(@ontology)

    if request.xhr?
      display = params[:callback].eql?('load') ? {full: true} : {display: "prefLabel"}
      @concept = @ontology.explore.single_class(display, params[:id])
      not_found if @concept.nil?
      show_ajax_request # process an ajax call
    else
      # Get the latest 'ready' submission, or fallback to any latest submission
      # TODO: change the logic here if the fallback will crash the visualization
      @submission = get_ontology_submission_ready(@ontology)  # application_controller

      @concept = @ontology.explore.single_class({full: true}, params[:id])
      not_found if @concept.nil?

      show_uri_request # process a full call
      render :file => '/ontologies/visualize', :use_full_path => true, :layout => 'ontology'
    end
  end

  def show_label
    cls_id = params[:concept]   # cls_id should be a full URI
    ont_id = params[:ontology]  # ont_id could be a full URI or an acronym

    if ont_id.to_i > 0
      params_cleanup_new_api()
      stop_words = ["controller", "action"]
      redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: stop_words)}", :status => :moved_permanently
      return
    end

    render plain: concept_label(ont_id, cls_id)
  end

  def show_definition
    if params[:ontology].to_i > 0
      params_cleanup_new_api()
      stop_words = ["controller", "action"]
      redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: stop_words)}", :status => :moved_permanently
      return
    end
    @ontology = LinkedData::Client::Models::Ontology.find(params[:ontology])
    cls = @ontology.explore.single_class(params[:concept])
    render :text => cls.definition
  end

  def show_tree
    if params[:ontology].to_i > 0
      params_cleanup_new_api()
      stop_words = ["controller", "action"]
      redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: stop_words)}", :status => :moved_permanently
      return
    end
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    if @ontology.nil?
      not_found
    else 
      get_class(params)   # application_controller
      render :partial => "ontologies/treeview"
    end
  end

  def property_tree
    if params[:ontology].to_i > 0
      params_cleanup_new_api()
      stop_words = ["controller", "action"]
      redirect_to "#{request.path}#{params_string_for_redirect(params, stop_words: stop_words)}", :status => :moved_permanently
      return
    end
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?
    @root = @ontology.property_tree
    render json: LinkedData::Client::Models::Property.properties_to_hash(@root.children)
  end

  # Renders a details pane for a given ontology/concept
  def details
    not_found if params[:conceptid].nil? || params[:conceptid].empty?

    if params[:ontology].to_i > 0
      orig_id = params[:ontology]
      params_cleanup_new_api()
      options = {stop_words: ["controller", "action", "id"]}
      redirect_to "#{request.path.sub(orig_id, params[:ontology])}#{params_string_for_redirect(params, options)}", :status => :moved_permanently
      return
    end

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?

    @concept = @ontology.explore.single_class({full: true}, CGI.unescape(params[:conceptid]))
    not_found if @concept.nil?

    if params[:styled].eql?("true")
      render :partial => "details", :layout => "partial"
    else
      render :partial => "details"
    end
  end

  def biomixer
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?

    @concept = @ontology.explore.single_class({full: true}, params[:conceptid])
    not_found if @concept.nil?

    @immediate_load = true

    render partial: "biomixer", layout: false
  end

# PRIVATE -----------------------------------------
private

  def show_ajax_request
    case params[:callback]
    when 'load' # Load pulls in all the details of a node
      gather_details
      render :partial => 'load'
    when 'children' # Children is called only for drawing the tree
      @children = @concept.explore.children(pagesize: 750).collection || []
      @children.sort!{|x,y| (x.prefLabel || "").downcase <=> (y.prefLabel || "").downcase} unless @children.empty?
      render :partial => 'child_nodes'
    end
  end

  # gathers the full set of data for a node
  def show_uri_request
    gather_details
    build_tree
  end

  def gather_details
    @mappings = get_concept_mappings(@concept)
    @notes = @concept.explore.notes
    @delete_mapping_permission = check_delete_mapping_permission(@mappings)
    update_tab(@ontology, @concept.id) #updates the 'history' tab with the current node
  end

  def build_tree
    # find path to root
    rootNode = @concept.explore.tree(include: "prefLabel,hasChildren,obsolete,subClassOf")
    @root = LinkedData::Client::Models::Class.new(read_only: true)
    @root.children = rootNode unless rootNode.nil?
  end


end
