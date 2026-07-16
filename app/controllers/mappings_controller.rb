# frozen_string_literal: true

require 'cgi'

class MappingsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include MappingStatistics,MappingsHelper

  layout :determine_layout
  before_action :authorize_and_redirect, only: [:create, :new, :destroy]

  MAPPINGS_URL = "#{LinkedData::Client.settings.rest_url}/mappings"

  def index
    ontology_list = LinkedData::Client::Models::Ontology.all.select { |o| !o.summaryOnly }
    ontologies_mapping_count = LinkedData::Client::HTTP.get("#{MAPPINGS_URL}/statistics/ontologies")
    ontologies_hash = {}
    ontology_list.each do |ontology|
      ontologies_hash[ontology.acronym] = ontology
    end

    # TODO_REV: Views support for mappings
    # views_list.each do |view|
    #   ontologies_hash[view.ontologyId] = view
    # end

    @options = {}
    if ontologies_mapping_count
      ontologies_mapping_count.members.each do |ontology_acronym|
        ontology = ontologies_hash[ontology_acronym.to_s]
        next if ontology.nil?

        mapping_count = ontologies_mapping_count[ontology_acronym]
        next if mapping_count.nil? || mapping_count.to_i.zero?

        select_text = "#{ontology.name} - #{ontology.acronym} (#{number_with_delimiter(mapping_count, delimiter: ',')})"
        @options[select_text] = ontology_acronym
      end
    end

    @options = @options.sort
  end

  def count
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    @mapping_counts = mapping_counts(@ontology.acronym)
    render partial: 'count'
  end

  def show
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:id]).first
    not_found if @ontology.nil?

    @target_ontology = LinkedData::Client::Models::Ontology.find(params[:target])
    not_found if @target_ontology.nil?

    page = params[:page] || 1
    ontologies = [@ontology.acronym, @target_ontology.acronym]
    @mapping_pages = LinkedData::Client::HTTP.get(MAPPINGS_URL,
                                                  { page: page, ontologies: ontologies.join(',') })
    @mappings = @mapping_pages.collection
    @delete_mapping_permission = check_delete_mapping_permission(@mappings)

    if @mapping_pages.nil? || @mapping_pages.collection.nil? || @mapping_pages.collection.empty?
      @mapping_pages = MappingPage.new
      @mapping_pages.page = 1
      @mapping_pages.pageCount = 1
      @mapping_pages.collection = []
    end

    total_results = @mapping_pages.pageCount * @mapping_pages.collection.length

    # This converts the mappings into an object that can be used with the pagination plugin
    @page_results = WillPaginate::Collection.create(@mapping_pages.page,
                                                    @mapping_pages.collection.length, total_results) do |pager|
      pager.replace(@mapping_pages.collection)
    end

    render partial: 'show'
  end

   def get_concept_table
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontologyid]).first
    @concept = @ontology.explore.single_class({ full: true }, params[:conceptid])

    @mappings = get_concept_mappings(@concept)
    @type = params[:type]
    @delete_mapping_permission = check_delete_mapping_permission(@mappings)
    render partial: 'mappings/concept_mappings', layout: false
  end

  def new
    if params[:ontology_from].present?
      @ontology_from = LinkedData::Client::Models::Ontology.find(params[:ontology_from])
    end
    if @ontology_from && params[:conceptid_from].present?
      @concept_from = @ontology_from.explore.single_class({ full: true }, params[:conceptid_from])
    end
    not_found if @concept_from.nil?

    # The target side of the form always starts empty
    @ontology_to = LinkedData::Client::Models::Ontology.new
    @concept_to = LinkedData::Client::Models::Class.new

    @mapping_relation_options = [
      ['Identical (skos:exactMatch)', 'http://www.w3.org/2004/02/skos/core#exactMatch'],
      ['Similar (skos:closeMatch)',   'http://www.w3.org/2004/02/skos/core#closeMatch'],
      ['Related (skos:relatedMatch)', 'http://www.w3.org/2004/02/skos/core#relatedMatch'],
      ['Broader (skos:broadMatch)',   'http://www.w3.org/2004/02/skos/core#broadMatch'],
      ['Narrower (skos:narrowMatch)', 'http://www.w3.org/2004/02/skos/core#narrowMatch']
    ]

    render layout: false
  end

  # POST /mappings
  # POST /mappings.xml
  def create
    source_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:map_from_bioportal_ontology_id]).first
    target_ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:map_to_bioportal_ontology_id]).first
    source = source_ontology.explore.single_class(params[:map_from_bioportal_full_id])
    target = target_ontology.explore.single_class(params[:map_to_bioportal_full_id])
    values = {
      classes: {
        source.id => source_ontology.id,
        target.id => target_ontology.id
      },
      creator: session[:user].id,
      relation: params[:mapping_relation],
      comment: params[:mapping_comment]
    }
    @mapping = LinkedData::Client::Models::Mapping.new(values: values)
    @mapping_saved = @mapping.save
    if @mapping_saved.errors
      raise Exception, @mapping_saved.errors
    else
      @delete_mapping_permission = check_delete_mapping_permission(@mapping_saved)
      render json: @mapping_saved
    end
  end

  def destroy
    errors = []
    successes = []
    mapping_ids = params[:mappingids].split(',')
    mapping_ids.each do |map_id|
      begin
        map_uri = "#{MAPPINGS_URL}/#{CGI.escape(map_id)}"
        result = LinkedData::Client::HTTP.delete(map_uri)
        raise Exception if !result.nil? # && result["errorCode"]

        successes << map_id
      rescue Exception => e
        errors << map_id
      end
    end
    render json: { success: successes, error: errors }
  end
end
