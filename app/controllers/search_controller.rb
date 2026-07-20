require 'uri'

class SearchController < ApplicationController

  skip_before_action :verify_authenticity_token

  layout :determine_layout

  def index
    @search_query = params[:query].nil? ? params[:q] : params[:query]
    @search_query ||= ""
  end

  # Class search across all ontologies, as plain JSON. Backs autocomplete
  # widgets (e.g. the new-mapping dialog's target class picker), unlike
  # json_search's legacy pipe-separated format.
  def classes
    query = params[:q].to_s.strip
    return render json: [] if query.length < 2

    # The trailing wildcard makes partial words match, but wildcard queries
    # bypass the API's exact-match boosting ("Contributory benefit" would
    # outrank "Contributor"), so results are re-ranked below
    wildcard_query = query.end_with?('*') ? query : "#{query}*"
    search_page = LinkedData::Client::Models::Class.search(wildcard_query, { pagesize: 20 })
    results = Array(search_page.collection).filter_map do |cls|
      next if cls.prefLabel.nil?

      {
        id: cls.id,
        prefLabel: cls.prefLabel,
        acronym: cls.links['ontology'].to_s.split('/').last
      }
    end
    results = results.sort_by.with_index { |r, i| [label_match_rank(r[:prefLabel], query), i] }
    render json: results
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

  # Ranks a label against the typed query: exact match, then a whole-word
  # prefix ("Contributor Role"), then any prefix ("Contributory"), then the
  # rest. Ties keep the search API's own ordering.
  def label_match_rank(label, query)
    label = label.to_s.downcase
    query = query.downcase.delete_suffix('*')
    return 0 if label == query
    return 3 unless label.start_with?(query)

    label[query.length]&.match?(/[[:alnum:]]/) ? 2 : 1
  end

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
