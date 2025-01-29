require 'uri'

class SearchController < ApplicationController

  skip_before_action :verify_authenticity_token

  layout :determine_layout

  def index
    @search_query = params[:query].nil? ? params[:q] : params[:query]
    @search_query ||= ""
  end

  def json_search
    if params[:q].nil?
      render :text => "No search class provided"
      return
    end
    check_params_query(params)
    check_params_ontologies(params)  # Filter on ontology_id
    search_page = LinkedData::Client::Models::Class.search(params[:q], params)
    @results = search_page.collection

    response = ""
    obsolete_response = ""
    separator = (params[:separator].nil?) ? "~!~" : params[:separator]
    for result in @results
      # TODO_REV: Format the response with type information, target information
      # record_type = format_record_type(result[:recordType], result[:obsolete])
      record_type = ""

      target_value = result.prefLabel
      case params[:target]
        when "name"
          target_value = result.prefLabel
        when "shortid"
          target_value = result.id
        when "uri"
          target_value = result.id
      end

      json = []
      json << "#{target_value}"
      json << " [obsolete]" if result.obsolete? # used by JS in ontologies/visualize to markup obsolete classes
      json << "|#{result.id}"
      json << "|#{record_type}"
      json << "|#{result.explore.ontology.acronym}"
      json << "|#{result.id}" # Duplicated because we used to have shortId and fullId
      json << "|#{result.prefLabel}"
      # This is nasty, but hard to workaround unless we rewrite everything (form_autocomplete, jump_to, crossdomain_autocomplete)
      # to use JSON from the bottom up. To avoid this, we pass a tab separated column list
      # Columns: synonym
      json << "|#{(result.synonym || []).join(";")}"
      if params[:id] && params[:id].split(",").length == 1
        json << "|#{CGI.escape((result.definition || []).join(". "))}#{separator}"
      else
        json << "|#{result.explore.ontology.name}"
        json << "|#{result.explore.ontology.acronym}"
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

  def format_record_type(record_type, obsolete = false)
    case record_type
      when "apreferredname"
        record_text = "Preferred Name"
      when "bconceptid"
        record_text = "Class ID"
      when "csynonym"
        record_text = "Synonym"
      when "dproperty"
        record_text = "Property"
      else
        record_text = ""
    end
    record_text = "Obsolete Class" if obsolete
    record_text
  end

end
