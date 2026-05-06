require 'uri'

class SearchController < ApplicationController
  include SearchAggregator, SearchContent, FederationHelper

  skip_before_action :verify_authenticity_token

  layout :determine_layout

  def index
    @search_query = params[:query] || params[:q] || ''
    params[:query] = nil
    @advanced_options_open = false
    @search_results = []
    @json_url = json_link("#{rest_url}/search", {})
    params[:portals] = params[:portals]&.join(',')

    return if @search_query.empty?

    params[:pagesize] = "150"

    set_federated_portals

    params[:ontologies] = nil if federated_request?

    @time = Benchmark.realtime do
      results = LinkedData::Client::Models::Class.search(@search_query, params)
      @federation_errors = federation_error(results) if federation_error?(results)
      results = results.collection


      @search_results = aggregate_results(@search_query, results)
      @federation_counts = federated_search_counts(@search_results)
    end
    @advanced_options_open = !search_params_empty?
    @json_url = json_link("#{rest_url}/search", params.permit!.to_h)
  end

  def json_search
    if params[:q].nil?
      render :plain => t('search.no_search_class_provided')
      return
    end
    check_params_query(params)
    check_params_ontologies(params)  # Filter on ontology_id
    if params["id"]&.eql?('All')
      params.delete("id")
      params.delete("ontologies")
    end
    search_page = LinkedData::Client::Models::Class.search(params[:q], params)

    @results = search_page.collection

    response = ""
    obsolete_response = ""
    separator = (params[:separator].nil?) ? "~!~" : params[:separator]

    for result in Array(@results)
      # TODO_REV: Format the response with type information, target information
      # record_type = format_record_type(result[:recordType], result[:obsolete])
      record_type = ""

      label = search_concept_label(result.prefLabel)
      target_value = label

      case params[:target]
      when "name"
        target_value = label
      when "shortid"
        target_value = result.id
      when "uri"
        target_value = result.id
      end

      acronym =  result.links["ontology"].split('/').last
      json = []
      json << "#{target_value}"
      json << " [obsolete]" if result.obsolete? # used by JS in ontologies/visualize to markup obsolete classes
      json << "|#{result.id}"
      json << "|#{record_type}"
      json << "|#{acronym}"
      json << "|#{result.id}" # Duplicated because we used to have shortId and fullId
      json << "|#{target_value}"
      # This is nasty, but hard to workaround unless we rewrite everything (form_autocomplete, jump_to, crossdomain_autocomplete)
      # to use JSON from the bottom up. To avoid this, we pass a tab separated column list
      # Columns: synonym
      json << "|#{(result.synonym || []).join(";")}"
      if params[:id] && params[:id].split(",").length == 1
        json << "|#{CGI.escape((result.definition || []).join(". "))}#{separator}"
      else
        json << "|#{acronym}"
        json << "|#{acronym}"
        json << "|#{CGI.escape((result.definition || []).join(". "))}#{separator}"
      end

      # Obsolete results go at the end
      if result.obsolete?
        obsolete_response << json.join
      else
        response << json.join
      end
    end

    # Obsolete results merge
    response << obsolete_response

    content_type = "text/html"
    if params[:response].eql?("json")
      response = response.gsub("\"","'")
      response = "#{params[:callback]}({data:\"#{response}\"})"
      content_type = "application/javascript"
    end

    render plain: response, content_type: content_type
  end

  def json_ontology_classes_search
    acronym = params[:ontology_acronym]
    query = params[:search].to_s
    page_size = (params[:page_size] || 25).to_i

    if acronym.blank? || query.blank?
      render json: []
      return
    end

    query = "#{query.strip}*" unless query.end_with?('*')

    search_page = LinkedData::Client::Models::Class.search(query, {
      ontologies: acronym,
      pagesize: page_size,
      also_search_obsolete: false,
      also_search_views: false,
      include: 'prefLabel,synonym,definition'
    })

    results = Array(search_page&.collection).map do |cls|
      ontology_link = cls.links && cls.links['ontology']
      ontology_acronym = ontology_link ? ontology_link.split('/').last : acronym
      label = main_language_label(cls.prefLabel) || cls.id

      {
        id: cls.id,
        name: cls.id,
        label: label,
        acronym: ontology_acronym,
        type: 'Class'
      }
    end

    render json: results
  end

  def json_ontology_content_search
    query = params[:search] || '*'
    page = (params[:page] || 1).to_i
    acronyms = params[:ontologies]&.split(',') || []
    page_size = (params[:page_size] || 10).to_i
    type = params[:types]&.split(',') || []
    show_ontologies = !params[:show_ontologies].eql?('false')


    results, page, next_page, total_count = search_ontologies_content(query: query,
                                         page: page,
                                         page_size: page_size,
                                         filter_by_ontologies: acronyms,
                                        filter_by_types: type,
                                        show_ontologies: show_ontologies)

    render json: results
  end

  private

  def check_params_query(params)
    params[:q] = params[:q].strip
    params[:q] = params[:q] + '*' unless params[:q].end_with?("*") # Add wildcard
  end

  def check_params_ontologies(params)
    params[:ontologies] ||= params[:id]
    if params[:ontologies]
      if params[:ontologies].include?(",")
        params[:ontologies] = params[:ontologies].split(",")
      else
        params[:ontologies] = [params[:ontologies]]
      end
      params[:ontologies] = params[:ontologies].join(",")
    end
  end

  def search_params
    [
      :ontologies, :categories,
      :also_search_properties, :also_search_obsolete, :also_search_views,
      :require_exact_match, :require_definition, :portals
    ]
  end

  def search_params_empty?
    (params[:lang].nil? || params[:lang].eql?('all')) &&
      search_params.all?{|key| params[key].nil? || params[key].empty?}
  end

end
