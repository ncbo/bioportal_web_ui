module MultiLanguagesHelper

  def portal_language_help_text
    t('language.portal_language_help_text')
  end

  def portal_languages
    {
      en: { badge: nil, disabled: false },
      fr: { badge: 'beta', disabled: false },
      it: { badge: 'coming', disabled: true },
      de: { badge: 'coming', disabled: true }
    }
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

    concept_value || concept.to_a.first
  end

  def main_language_label(label)
    select_language_label(label)&.last
  end

  def selected_language_label(label)
    language_hash(label).values.first
  end

  def content_language_selector(id: 'content_language', name: 'content_language')
    languages, selected = content_languages
    select_tag(name, options_for_select(languages, selected || 'all'), class: "form-select",
               data: { controller: "language-change", 'language-change-section-value': "classes", action: "change->language-change#dispatchLangChangeEvent" }) if languages&.length > 1
  end

  def content_languages(submission = @submission || @submission_latest)
    current_lang = request_lang(submission).downcase
    submission_lang = submission_languages(submission)
    # Transform each language into a select option
    submission_lang = submission_lang.map do |lang|
      lang = lang.split('/').last.upcase
      lang = ISO_639.find(lang.to_s.downcase)
      next nil unless lang
      [lang.english_name, lang.alpha2]
    end.compact

    [submission_lang, current_lang]
  end

  def portal_lang
    session[:locale] || 'en'
  end

  def request_lang(submission = @submission || @submission_latest)
    lang = params[:language] || params[:lang]
    lang = submission_languages(submission)&.first unless lang
    lang = portal_lang unless lang
    lang
  end

  def lang_code(code_in)
    code_out = code_in
    case code_in
    when 'en'
      code_out = 'us'
    when 'ar'
      code_out = 'sa'
    when 'hi'
      code_out = 'in'
    when 'ur'
      code_out =  'pk'
    when 'zh'
      code_out =  'cn'
    when 'ja'
      code_out = 'jp'
    end
    code_out
  end

end
