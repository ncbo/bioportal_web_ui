class InstancesController < ApplicationController
  include InstancesHelper
  def index_by_ontology
    get_ontology(params)
    custom_render get_instances_by_ontology_json(@ontology, get_query_parameters)
  end

  def index_by_class
    get_ontology(params)
    get_class(params)
    custom_render get_instances_by_class_json(@concept, get_query_parameters)
  end

  def show
    @instance = get_instance_details_json(params[:ontology_id], params[:instance_id], {include: 'all'})
    render partial: 'instances/instance_details'
  end

  private

  def get_ontology(params)
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology]).first
    not_found if @ontology.nil?
  end
  # json render + adding next and prev pages links
  def custom_render(instances)
    instances[:collection].map! { |i| add_labels_to_print(i, @ontology.acronym)}
    if (instances.respond_to? :links) && (!instances.respond_to? :errors)
      instances.links = {
        nextPage: get_page_link(instances.nextPage),
        prevPage: get_page_link(instances.prevPage)
      }
    end

    render json: instances
  end

  def get_page_link(page_number)
    return nil if page_number.nil?

    if request.query_parameters.has_key?(:page)
      request.original_url.gsub(/page=\d+/, "page=#{page_number}")
    elsif request.query_parameters.empty?
      request.original_url + "?" + "page=#{page_number}"
    else
      request.original_url + "&" + "page=#{page_number}"
    end
  end

  def get_query_parameters
    request.query_parameters.slice(:include, :display, :page, :pagesize, :search , :sortby , :order) || {}
  end
end