module AutoCompleteHelper

  def ontologies_autocomplete
    render OntologySearchInputComponent.new
  end

  def ontologies_content_autocomplete(id: '', name: '', search: '', ontologies: [], types: [], search_icon_type: 'home')
    render SearchInputComponent.new(id: id, name: name, ajax_url: "#{ajax_search_ontologies_content_path}?ontologies=#{ontologies.join(',')}&types=#{types.join(',')}&search=#{search}",
                                    item_base_url: "", id_key: 'id', placeholder: t("ontologies.ontology_search_prompt"),
                                    use_cache: false, search_icon_type: search_icon_type, display_all: true,
                                    actions_links: { search_ontology_content: "/search?query=o", browse_all_ontologies: "/ontologies?search=o" }) do |s|
      s.template do
        link_to "LINK", class: "search-content", 'data-turbo-frame': '_top' do
          content_tag(:div, class: 'search-element home-searched-ontology flex-column') do
            content_tag(:p, "LABEL") + content_tag(:small, "NAME") + content_tag(:small, "ACRONYM", class: 'text-primary')
          end + content_tag(:p, "TYPE", class: 'home-result-type')
        end
      end
    end
  end

  def ontology_content_autocomplete(search: '', ontologies: [], types: [])
    ontologies_content_autocomplete(ontologies: ontologies, types: types, search: "#{search}")
  end


  def ontology_classes_content_autocomplete(ontology_acronym:, id: '', name: '', search: '', search_icon_type: nil)
    render SearchInputComponent.new(id: id, name: name,
                                    ajax_url: "/ajax/search/ontologies/#{ontology_acronym}/classes?search=#{search}",
                                    item_base_url: "", id_key: 'id', placeholder: t("ontologies.class_search_prompt"),
                                    use_cache: false, search_icon_type: search_icon_type, display_all: true) do |s|
      s.template do
        content_tag(:div, class: "search-content clickable-result", data: { action: "click->class-picker#addResult" }, 'data-turbo-frame': '_top') do
          content_tag(:div, class: 'search-element home-searched-ontology flex-column') do
            content_tag(:p, "LABEL", class: "class-label_name") + content_tag(:small, "NAME", class: "class-uri") + content_tag(:small, "ACRONYM", class: 'text-primary')
          end + content_tag(:p, "TYPE", class: 'home-result-type')
        end
      end
    end
  end

  def subjects_ontologies_content_autocomplete(id: '', name: '', search: '', ontologies: [], types: [], search_icon_type: nil)
    if ontologies.empty?
      render Display::AlertComponent.new(type:'warning', closable: false, message: t('submission_inputs.theme_taxonomy_not_set'))
    else
      render SearchInputComponent.new(id: id, name: name, ajax_url: "#{ajax_search_ontologies_content_path}?ontologies=#{ontologies.join(',')}&types=#{types.join(',')}&show_ontologies=false&search=#{search}",
                                      item_base_url: "", id_key: 'id', placeholder: t("ontologies.ontology_search_prompt"),
                                      use_cache: false, search_icon_type: search_icon_type, display_all: true) do |s|
        s.template do
          content_tag(:div, class: "search-content clickable-result", data: {action: "click->class-picker#addResult"},'data-turbo-frame': '_top') do
            content_tag(:div, class: 'search-element home-searched-ontology flex-column') do
              content_tag(:p, "LABEL", class: "class-label_name") + content_tag(:small, "NAME", class: "class-uri") + content_tag(:small, "ACRONYM", class: 'text-primary')
            end + content_tag(:p, "TYPE", class: 'home-result-type')
          end
        end
      end
    end
  end

end