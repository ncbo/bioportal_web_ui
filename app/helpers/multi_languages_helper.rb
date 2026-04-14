module MultiLanguagesHelper
  include OntologiesHelper, ComponentsHelper
  def portal_lang
    session[:locale] || 'en'
  end

  def request_lang
    lang = params[:language] || params[:lang]
    lang = portal_lang unless lang
    lang.upcase
  end

  def portal_language_help_text
    t('language.portal_language_help_text')
  end

  def portal_languages
    {
      en: { badge: nil, disabled: false },
      fr: { badge: nil, disabled: false },
      it: { badge: 'coming', disabled: true },
      de: { badge: 'coming', disabled: true }
    }
  end

  def portal_language_enabled?(lang)
    portal_languages.reject { |_k, x| x[:disabled] }.keys.include?(lang)
  end

  def portal_language_selector
    languages = portal_languages
    selected_language = portal_lang
    selected_language = content_tag(:span, selected_language.upcase, data: { controller: 'tooltip' }, title: portal_language_help_text)
    render DropdownButtonComponent.new do |d|
      d.header { selected_language }
      d.section(divide: false, selected_index: languages.find_index(selected_language)) do |s|
        languages.each do |lang, metadata|
          s.item do
            text = content_tag(:div, class: 'd-flex align-items-center') do
              content_tag(:span, render(LanguageFieldComponent.new(value: lang, auto_label: true)), class: 'mr-1') + beta_badge(metadata[:badge])
            end
            link_options = { data: { turbo: false } }

            if metadata[:disabled]
              link_options[:class] = 'disabled-link'
              link_options[:disabled] = 'disabled'
            end

            link_to(text, "/locale/#{lang}", link_options)
          end
        end

      end
    end
  end

  def search_language_help_text
    content_tag(:div, style: 'width: 300px; text-align: center') do
      t('language.search_language_help_text')
    end
  end

  def search_languages
    # top ten spoken languages
    portal_languages.keys + %w[zh es hi ar bn pt ru ur id]
  end

  def search_language_selector(id: 'search_language', name: 'search_language', selected: nil)
    render Input::LanguageSelectorComponent.new(id: id, name: name, enable_all: true,
                                                languages: search_languages,
                                                'data-select-input-searchable-value': false,
                                                title: search_language_help_text,
                                                selected: selected&.to_sym)

  end

  def content_languages(submission = @submission || @submission_latest)
    current_lang = request_lang.downcase
    submission_lang = submission_languages(submission)

    submission_lang = [current_lang.to_s]  if submission_lang.empty?

    # Transform each language into a select option
    submission_lang = submission_lang.map do |lang|
      code, name = find_language_code_name(lang)
      next nil unless code
      [code, name]
    end.compact

    [submission_lang, current_lang]
  end

  def find_language_code_name(language)
    original_lang = language.to_s.split('/').last.upcase
    lang, country = original_lang.split('-')

    if country
      lang = ISO3166::Country.find_country_by_alpha2(country)
      return nil unless lang

      [original_lang, lang.nationality]
    else
      lang = ISO_639.find(lang.to_s.downcase)
      return nil unless lang

      [lang.alpha2, lang.english_name]
    end
  end

  def content_language_help_text
    content_tag(:div, style: 'width: 350px;') do
      concat content_tag(:div, t('language.content_language_help_text_1'))
      concat(content_tag(:div, class: "mt-1") do
        content_tag(:span, t('language.content_language_help_text_2')) + edit_sub_languages_button
      end)
    end
  end

  def content_language_selector(id: 'content_language', name: 'content_language')
    languages, selected = content_languages
    render Input::LanguageSelectorComponent.new(id: id, name: name, enable_all: true,
                                                languages: languages,
                                                selected: selected || request_lang,
                                                'data-tooltip-interactive-value': true,
                                                'data-select-input-searchable-value': false,
                                                title: content_language_help_text)

  end

  def language_hash(concept_label, multiple: false)
    if concept_label.is_a?(Array)
      return concept_label.first unless multiple
      return concept_label
    end

    return concept_label.to_h.reject { |key, _| %i[links context].include?(key) } if concept_label.is_a?(OpenStruct)

    concept_label
  end

  def sorted_labels(labels)
    Array(labels).sort_by { |label| label['prefLabel'].is_a?(String) ? label['prefLabel'] : label['prefLabel'].last }
  end

  def select_language_label(concept_label, platform_languages = %i[en fr])
    concept_value = nil

    concept = language_hash(concept_label)

    return ['@none', concept] if concept.is_a?(String)

    concept = concept.to_h

    platform_languages.each do |lang|
      if concept[lang]
        concept_value = [lang, concept[lang]]
        break
      end
    end

    concept_value || concept.reject { |k| k.to_s.eql?('@none') }.first || concept.first
  end

  def main_language_label(label)
    select_language_label(label)&.last
  end

  # @param label String | Array | OpenStruct
  def display_in_multiple_languages(label, style_as_badge: false, show_max: 5)
    if label.blank?
      return render Display::AlertComponent.new(message: t('ontology_details.concept.no_preferred_name_for_selected_language'),
                                                type: "warning",
                                                closable: true)
    end

    label = label.to_h.reject { |key, _| %i[links context].include?(key) } if label.is_a?(OpenStruct)

    if label.is_a?(String)
      content_tag(:p, label)
    elsif label.is_a?(Array)
      list_items_component(max_items: show_max) do |r|
        label.map do |x|
          r.container { content_tag(:span, x, class: style_as_badge ? 'badge badge-pill p-2' : '', style: 'font-style: italic; color:var(--primary-color); background-color: var(--light-color);').html_safe }        
        end
      end
    else
      content_tag(:div) do
        raw(label.map do |key, value|
          Array(value).map do |v|
            content_tag(:div, class: 'definition') do
              concat content_tag(:span, v)
              concat content_tag(:span, key.upcase, class: 'badge badge-secondary ml-1') unless key.to_s.upcase.eql?('NONE') || key.to_s.upcase.eql?('@NONE')
            end
          end.join
        end.join)
      end
    end
  end

  def selected_language_label(label)
    language_hash(label).values.first
  end
end
