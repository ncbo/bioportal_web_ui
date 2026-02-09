class KnowledgeGraphsController < ApplicationController
  def index
    @title = "Knowledge Graphs"
    @all_knowledge_graphs = KgRegistry.all

    @query = params[:q].to_s.strip
    @category = params[:category].to_s.strip
    @status = params[:status].to_s.strip
    @domain = params[:domain].to_s.strip

    @categories = @all_knowledge_graphs.map { |kg| kg[:category] }.compact.uniq.sort
    @statuses = @all_knowledge_graphs.map { |kg| kg[:activity_status] }.compact.uniq.sort
    @domains = @all_knowledge_graphs.flat_map { |kg| Array(kg[:domains]) }.compact.uniq.sort

    @knowledge_graphs = filter_knowledge_graphs(@all_knowledge_graphs)
  end

  def show
    @knowledge_graph = KgRegistry.find(params[:id])
    not_found("Knowledge graph not found") if @knowledge_graph.nil?

    @title = @knowledge_graph[:name] || "Knowledge Graph"

    @bioportal_apikey_present = LinkedData::Client.settings.apikey.to_s.strip.present?
    @kg_sources = KgOntologyMapper.sources_from(@knowledge_graph)
    @kg_mappings = KgOntologyMapper.map_sources(@kg_sources, skip_lookup: !@bioportal_apikey_present)
  end

  private

  def filter_knowledge_graphs(resources)
    filtered = resources

    if @query.present?
      q = @query.downcase
      filtered = filtered.select do |kg|
        haystack = [
          kg[:name],
          kg[:id],
          kg[:label],
          kg[:description]
        ] + Array(kg[:synonyms])
        haystack.compact.any? { |value| value.to_s.downcase.include?(q) }
      end
    end

    if @category.present?
      filtered = filtered.select { |kg| kg[:category].to_s.casecmp(@category).zero? }
    end

    if @status.present?
      filtered = filtered.select { |kg| kg[:activity_status].to_s.casecmp(@status).zero? }
    end

    if @domain.present?
      domain = @domain.downcase
      filtered = filtered.select do |kg|
        Array(kg[:domains]).map { |d| d.to_s.downcase }.include?(domain)
      end
    end

    filtered.sort_by { |kg| kg[:name].to_s.downcase }
  end
end
