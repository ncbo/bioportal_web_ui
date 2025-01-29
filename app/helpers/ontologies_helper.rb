# frozen_string_literal: true
require 'iso-639'

module OntologiesHelper

  LANGUAGE_FILTERABLE_SECTIONS = %w[classes].freeze

  def additional_details
    return '' if $ADDITIONAL_ONTOLOGY_DETAILS.nil? || $ADDITIONAL_ONTOLOGY_DETAILS[@ontology.acronym].nil?

    details = $ADDITIONAL_ONTOLOGY_DETAILS[@ontology.acronym]
    html = []
    details.each do |title, value|
      html << content_tag(:tr) do
        html << content_tag(:td, title)
        html << content_tag(:td, raw(value))
      end
    end
    html.join('')
  end

  def count_links(ont_acronym, page_name = 'summary', count = 0)
    ont_url = "/ontologies/#{ont_acronym}"
    if count.nil? || count.zero?
      return '0'
    else
      return "<a href='#{ont_url}/?p=#{page_name}'>#{number_with_delimiter(count, delimiter: ',')}</a>"
    end
  end

  def classes_link(ontology, count)
    return '0' if ontology.summaryOnly || count.nil? || count.zero?

    count_links(ontology.ontology.acronym, 'classes', count)
  end

  # Creates a link based on the status of an ontology submission
  def download_link(submission, ontology = nil)
    ontology ||= @ontology
    if submission.ontology.summaryOnly
      link = 'N/A - metadata only'
    else
      uri = submission.id + "/download?apikey=#{get_apikey}"
      link = "<a href='#{uri}' 'rel='nofollow'>#{submission.pretty_format}</a>"
      latest = ontology.explore.latest_submission({ include_status: 'ready' })
      if latest && latest.submissionId == submission.submissionId
        link += " | <a href='#{ontology.id}/download?apikey=#{get_apikey}&download_format=csv' rel='nofollow'>CSV</a>"
        if !latest.hasOntologyLanguage.eql?('UMLS')
          link += " | <a href='#{ontology.id}/download?apikey=#{get_apikey}&download_format=rdf' rel='nofollow'>RDF/XML</a>"
        end
      end
      unless submission.diffFilePath.nil?
        uri = submission.id + "/download_diff?apikey=#{get_apikey}"
        link = link + " | <a href='#{uri} 'rel='nofollow'>Diff</a>"
      end
    end
    link
  end

  def mappings_link(ontology, count)
    return '0' if ontology.summaryOnly || count.nil? || count.zero?

    count_links(ontology.ontology.acronym, 'mappings', count)
  end

  def notes_link(ontology, count)
    count_links(ontology.ontology.acronym, 'notes', count)
  end

  # Creates a link based on the status of an ontology submission
  def status_link(submission, latest = false, target = '')
    version_text = submission.version.nil? || submission.version.length == 0 ? 'unknown' : submission.version
    status_text = " <span class='ontology_submission_status'>" + submission_status2string(submission) + '</span>'
    if submission.ontology.summaryOnly || latest == false
      version_link = version_text
    else
      version_link = "<a href='/ontologies/#{submission.ontology.acronym}?p=classes' #{target.empty? ? '' : "target='#{target}'"}>#{version_text}</a>"
    end
    version_link + status_text
  end

  def new_view_link
    if session[:user].nil?
      link_to(login_index_path(redirect: new_ontology_path), { 'aria-label': 'Create view', title: 'Create view' }) do
        content_tag(:i, '', class: 'fas fa-lg fa-plus-circle', aria: { hidden: 'true' }).html_safe
      end
    else
      link_to(new_ontology_path, { 'aria-label': 'Create view', title: 'Create view' }) do
        content_tag(:i, '', class: 'fas fa-lg fa-plus-circle', aria: { hidden: 'true' }).html_safe
      end
    end
  end

  def submission_status2string(sub)
    # Massage the submission status into a UI string
    # submission status values, from:
    # https://github.com/ncbo/ontologies_linked_data/blob/master/lib/ontologies_linked_data/models/submission_status.rb
    # "UPLOADED", "RDF", "RDF_LABELS", "INDEXED", "METRICS", "ANNOTATOR", "ARCHIVED"  and 'ERROR_*' for each.
    # Strip the URI prefix from the status codes (works even if they are not URIs)
    # The order of the codes must be assumed to be random, it is not an entirely
    # predictable sequence of ontology processing stages.
    codes = sub.submissionStatus.map { |s| s.split('/').last }
    errors = codes.select { |c| c.start_with? 'ERROR' }.map { |c| c.gsub("_", " ").split(/(\W)/).map(&:capitalize).join }.compact
    status = []
    status.push('Parsed') if (codes.include? 'RDF') && (codes.include? 'RDF_LABELS')
    # The order of this array imposes an oder on the UI status code string
    status_list = ['INDEXED', 'METRICS', 'ANNOTATOR', 'ARCHIVED']
    status_list.insert(0, 'UPLOADED') unless status.include?('Parsed')
    status_list.each do |c|
      status.push(c.capitalize) if codes.include? c
    end
    status.concat errors
    return '' if status.empty?

    '(' + status.join(', ') + ')'
  end

  # Link for private/public/licensed ontologies
  def visibility_link(ontology)
    ont_url = "/ontologies/#{ontology.acronym}" # 'ontology' is NOT a submission here
    page_name = 'summary'  # default ontology page view for visibility link
    link_name = 'Public'   # default ontology visibility
    if ontology.summaryOnly
      link_name = 'Summary Only'
    elsif ontology.private?
      link_name = 'Private'
    elsif ontology.licensed?
      link_name = 'Licensed'
    end
    "<a href='#{ont_url}/?p=#{page_name}'>#{link_name}</a>"
  end

  def visits_data(ontology = nil)
    ontology ||= @ontology

    return nil unless @analytics && @analytics[ontology.acronym.to_sym]

    return @visits_data if @visits_data

    visits_data = { visits: [], labels: [] }
    years = @analytics[ontology.acronym.to_sym].to_h.keys.map { |e| e.to_s.to_i }.select { |e| e > 0 }.sort
    now = Time.now
    years.each do |year|
      months = @analytics[ontology.acronym.to_sym].to_h[year.to_s.to_sym].to_h.keys.map { |e| e.to_s.to_i }.select { |e| e > 0 }.sort
      months.each do |month|
        # No good data prior to Oct 2013
        next if now.year == year && now.month <= month || (year == 2013 && month < 10)

        visits_data[:visits] << @analytics[ontology.acronym.to_sym].to_h[year.to_s.to_sym][month.to_s.to_sym]
        visits_data[:labels] << DateTime.parse("#{year}/#{month}").strftime("%b %Y")
      end
    end
    @visits_data = visits_data
  end

  def acronyms(ontologies)
    ontologies.present? ? ontologies.map { |ont| ont.acronym } : []
  end

  def selected_section?(section_title)
    current_section.eql?(section_title)
  end

  def submission_ready?(submission)
    Array(submission&.submissionStatus).include?('RDF')
  end

  def concept_label_to_show(submission: @submission_latest)
    submission&.hasOntologyLanguage == 'SKOS' ? 'concepts' : 'classes'
  end

  def sections_to_show
    sections = ['summary']
    if !@ontology.summaryOnly && (submission_ready?(@submission_latest) || @old_submission_ready)
      sections += ['classes']
      sections += %w[properties]
      #sections += %w[schemes collections] if skos?
      #sections += %w[instances] unless skos?
      #sections += %w[notes mappings widgets sparql]
      sections += %w[notes mappings widgets]
    end
    sections
  end

  def lazy_load_section(section_title, &block)
    if current_section.eql?(section_title)
      block.call
    else
      render TurboFrameComponent.new(id: section_title, src: "/ontologies/#{@ontology.acronym}?p=#{section_title}",
                                     loading: Rails.env.development? ? "lazy" : "eager",
                                     target: '_top', data: { "turbo-frame-target": "frame" })
    end
  end
  def language_selector_hidden_tag(section)
    hidden_field_tag "language_selector_hidden_#{section}", '',
                     data: { controller: "language-change", 'language-change-section-value': section, action: "change->language-change#dispatchLangChangeEvent" }
  end

  def section_data(section_title)
    if ontology_data_section?(section_title)
      url_value = selected_section?(section_title) ? request.fullpath : "/ontologies/#{@ontology.acronym}?p=#{section_title}"
      { controller: "history turbo-frame", 'turbo-frame-url-value': url_value, action: "lang_changed->history#updateURL lang_changed->turbo-frame#updateFrame" }
    else
      {}
    end
  end



  def visits_chart_dataset(visits_data)
    visits_chart_dataset_array({'Visits': visits_data})
  end

  def visits_chart_dataset_array(visits_data, fill: true)
    visits_data = visits_data.map do |label , x|
      {
        label: label,
        data: x,
        borderWidth: 2,
        borderRadius: 5,
        borderSkipped: false,
        cubicInterpolationMode: 'monotone',
        tension: 0.4,
        fill: fill
      }
    end
    visits_data.to_json
  end

  def change_requests_enabled?(ontology_acronym)
    return false unless Rails.configuration.change_request[:ontologies].present?

    Rails.configuration.change_request[:ontologies].include? ontology_acronym.to_sym
  end

  def current_section
    (params[:p]) ? params[:p] : 'summary'
  end

  def ontology_data_sections
    LANGUAGE_FILTERABLE_SECTIONS
  end

  def ontology_data_section?(section_title = current_section)
    ontology_data_sections.include?(section_title)
  end

  def language_selector_tag(name)
    content_language_selector(id: name, name: name)
  end

  def submission_languages(submission = @submission)
    Array(submission&.naturalLanguage).map { |natural_language| natural_language.split('/').last }.compact
  end

  def abbreviations_to_languages(abbreviations)
    # Use iso-639 gem to convert language codes to their English names
    languages = abbreviations.map do |abbr|
      language = ISO_639.find_by_code(abbr) || ISO_639.find_by_english_name(abbr)
      language ? language.english_name : abbr
    end
    languages.sort
  end

end
