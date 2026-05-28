module MappingsHelper

  def mappings_rest_url(ontologies = nil, display = nil)
    url = rest_url + mappings_path
    params = []
    params << "ontologies=#{ontologies}" if ontologies
    params << "display=#{display}" if display
    url + (params.any? ? "?#{params.join('&')}" : '')
  end

  # Used to replace the full URI by the prefixed URI
  RELATIONSHIP_PREFIX = {
    'http://www.w3.org/2004/02/skos/core#' => 'skos:',
    'http://www.w3.org/2000/01/rdf-schema#' => 'rdfs:',
    'http://www.w3.org/2002/07/owl#' => 'owl:',
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#' => 'rdf:',
    'http://purl.org/linguistics/gold/' => 'gold:',
    'http://lemon-model.net/lemon#' => 'lemon:'
  }

  INTERPORTAL_HASH = $INTERPORTAL_HASH

  def mapping_links(mapping, concept)
    target_concept = mapping.classes.select do |c|
      c.id != concept.id && c.links['ontology'] != concept.links['ontology']
    end.first
    target_concept ||= mapping.classes.last
    process = mapping.process || {}

    if inter_portal_mapping?(target_concept)
      cls_link = target_concept.id
      ont_name = target_concept.links['ontology']
      ont_link = link_to ont_name, get_inter_portal_ui_link(ont_name, process['name']), target: '_blank'
      source_tooltip = 'Internal-portal'
    elsif internal_mapping?(target_concept)
      ont_name = target_concept.links['ontology'].split('/').last
      ont_link = link_to ont_name, ontology_path(ont_name), 'data-turbo-frame': '_top'
      cls_link = raw(get_link_for_cls_ajax(target_concept.id, ont_name, '_top'))
      source_tooltip = 'Internal'
    else
      cls_label = ExternalLinkTextComponent.new(text: target_concept.links['self']).call
      cls_link = raw("<a href='#{target_concept.links['self']}' target='_blank'>#{cls_label}</a>")
      ont_name = target_concept.links['ontology']
      ont_link = link_to ExternalLinkTextComponent.new(text: ont_name).call, target_concept.links['ontology'],
                         target: '_blank'
      source_tooltip = 'External'
    end

    [cls_link, ont_link, source_tooltip]
  end

  def mapping_prefixed_relations(mapping)
    process = mapping.process || {}
    Array(process[:relation]).each { |relation| get_prefixed_uri(relation) }
  end

  def mapping_type_tooltip(map)
    relations = mapping_prefixed_relations(map)
    process = map.process || {}
    type = if map.source.to_s.include? 'SKOS'
             'SKOS'
           else
             map.source
           end
    types_description = {
      'CUI' => t('mappings.types_description.cui'),
      'LOOM' => t('mappings.types_description.loom'),
      'REST' => t('mappings.types_description.rest'),
      'SAME_URI' => t('mappings.types_description.same_uri'),
      'SKOS' => t('mappings.types_description.skos')
    }
    type_tooltip = content_tag(:div, "#{map.source} #{relations.join(', ')} : #{types_description[type]} #{process[:source_name]}".strip, style: 'width: 300px')
    [type, type_tooltip]
  end

  # a little method that returns the uri with a prefix : http://purl.org/linguistics/gold/translation become gold:translation
  def get_prefixed_uri(uri)
    RELATIONSHIP_PREFIX.each { |k, v| uri.sub!(k, v) }
    uri
  end

  def ajax_to_internal_cls(cls)
    cls_id = cls.id
    ont_acronym = cls.links['ontology'].split('/').last
    get_link_for_cls_ajax(cls_id, ont_acronym, '_blank')
  end

  # to get the apikey from the interportal instance of the interportal class.
  # The best way to know from which interportal instance the class came is to compare the UI url
  def get_inter_portal_acronym(class_ui_url)
    if !INTERPORTAL_HASH.nil?
      INTERPORTAL_HASH.each do |key, value|
        if class_ui_url.start_with?(value['ui'])
          return key
        else
          return nil
        end
      end
    end
  end

  def ajax_to_external_cls(cls)
    class_uri = cls.id
    text = if class_uri.include? '#'
             class_uri.split('#')[-1]
           else
             class_uri.split('/')[-1]
           end
    text = render(ExternalLinkTextComponent.new(text: text))
    link_to text, cls.links['self'], target: '_blank'
  end

  # Replace the inter_portal mapping ontology URI (that link to the API) by the link to the ontology in the UI
  def get_inter_portal_ui_link(uri, process_name)
    process_name = '' if process_name.nil?
    interportal_acronym = process_name.split(' ')[2]
    if interportal_acronym.nil? || interportal_acronym.empty? || INTERPORTAL_HASH[interportal_acronym].nil?
      uri
    else
      uri.sub!(INTERPORTAL_HASH[interportal_acronym]['api'], INTERPORTAL_HASH[interportal_acronym]['ui'])
    end
  end

  def internal_mapping?(cls)
    cls.links['self'].to_s.start_with?(LinkedData::Client.settings.rest_url) || ($LOCAL_IP.present? && cls.links['self'].to_s.include?($LOCAL_IP))
  end

  def inter_portal_mapping?(cls)
    !internal_mapping?(cls) && cls.links.has_key?('ui')
  end

  def type?(type)
    @mapping_type.nil? && type.eql?('internal') || @mapping_type.eql?(type)
  end

  def concept_mappings_loader(ontology_acronym:, concept_id:)
    content_tag(:span, id: 'mapping_count') do
      concat(content_tag(:div, class: 'concepts-mapping-count ml-1 mr-1') do
        render(TurboFrameComponent.new(
          id: 'mapping_count',
          src: "/ajax/mappings/get_concept_table?ontologyid=#{ontology_acronym}&conceptid=#{CGI.escape(concept_id)}",
          loading: 'lazy'
        )) do |t|
          concat(t.loader { render(LoaderComponent.new(small: true)) })
        end
      end)
    end
  end

  def client_filled_modal
    link_to_modal '', ''
  end

  def mappings_bubble_view_legend
    content_tag(:div, class: 'mappings-bubble-view-legend') do
      mappings_legend_section(t('mappings.bubble_view_legend.bubble_size'),
                              t('mappings.bubble_view_legend.bubble_size_desc'), 'mappings-bubble-size-legend') +
        mappings_legend_section(
          t('mappings.bubble_view_legend.color_degree'), t('mappings.bubble_view_legend.color_degree_desc'), 'mappings-bubble-color-legend') +
        content_tag(:div, class: 'content-container') do
          content_tag(:div, class: 'bubble-view-legend-item') do
            content_tag(:div, class: 'title') do
              content_tag(:div, t('mappings.bubble_view_legend.yellow_bubble'),
                          class: 'd-inline') + content_tag(:span, t('mappings.bubble_view_legend.selected_bubble'))
            end +
              content_tag(:div, class: 'mappings-bubble-size-legend d-flex justify-content-center') do
                content_tag(:div, '', class: 'bubble yellow')
              end
          end
        end
    end
  end

  def mappings_legend_section(title_text, description_text, css_class)
    content_tag(:div, class: 'content-container') do
      content_tag(:div, class: 'bubble-view-legend-item') do
        content_tag(:div, class: 'title') do
          content_tag(:div, "#{title_text} ", class: 'd-inline') +
            content_tag(:span, description_text)
        end +
          mappings_legend(css_class)
      end
    end
  end

  def mappings_legend(css_class)
    content_tag(:div, class: css_class) do
      content_tag(:div, t('mappings.bubble_view_legend.less_mappings'), class: 'mappings-legend-text') +
        (1..6).map { |i| content_tag(:div, '', class: "bubble bubble#{i}") }.join.html_safe +
        content_tag(:div, t('mappings.bubble_view_legend.more_mappings'), class: 'mappings-legend-text')
    end
  end
end
