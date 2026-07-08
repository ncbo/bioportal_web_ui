# frozen_string_literal: true

module ChangeRequestsHelper
  def change_request_success_message(issue)
    url = link_to 'details', issue['url'], target: '_blank'
    raw "Your change request was successfully submitted! View the #{url} on GitHub."
  end

  def change_request_alert_context
    flash.notice.present? ? 'alert-success' : 'alert-danger'
  end

  def edit_definition_button(definition)
    return unless change_requests_enabled?(@ontology.acronym)

    link_to(change_requests_edit_definition_path(concept_id: @concept.id, concept_label: @concept.prefLabel,
                                                 concept_definition: definition, ont_acronym: @ontology.acronym),
            role: 'button', class: 'btn btn-link', 'aria-label': 'Edit definition',
            data: { 'turbo': true, 'turbo-stream': 'true', 'turbo-frame': '_top' }) do
      inline_svg_tag('icons/pen.svg', class: 'svg-icon svg-icon-lg', aria_hidden: true)
    end
  end

  def add_synonym_button
    return unless change_requests_enabled?(@ontology.acronym)

    link_to(change_requests_create_synonym_path(concept_id: @concept.id, concept_label: @concept.prefLabel,
                                                ont_acronym: @ontology.acronym),
            role: 'button',
            class: 'btn btn-link p-0',
            aria: { label: 'Create synonym' },
            data: { 'bs-toggle': 'modal', 'bs-target': '#changeRequestModal' },
            remote: 'true') do
      inline_svg_tag('icons/plus-circle.svg', class: 'svg-icon svg-icon-lg', aria_hidden: true)
    end
  end

  def remove_synonym_button
    return unless change_requests_enabled?(@ontology.acronym)

    if @concept.synonym.blank?
      tag.a role: 'button', class: 'btn btn-link disabled p-0', aria: { disabled: true } do
        inline_svg_tag('icons/minus-circle.svg', class: 'svg-icon svg-icon-lg', aria_hidden: true)
      end
    else
      link_to(change_requests_remove_synonym_path(concept_id: @concept.id, concept_label: @concept.prefLabel,
                                                  ont_acronym: @ontology.acronym, concept_synonyms: @concept.synonym),
              role: 'button', class: 'btn btn-link p-0', aria: { label: 'Remove synonym' },
              data: { 'bs-toggle': 'modal', 'bs-target': '#changeRequestModal' }, remote: 'true') do
        inline_svg_tag('icons/minus-circle.svg', class: 'svg-icon svg-icon-lg', aria_hidden: true)
      end
    end
  end

  def synonym_qualifier_select(form)
    options = [%w[exact exact], %w[narrow narrow], %w[broad broad], %w[related related]]
    form.select :qualifier, options_for_select(options, 0), {}, { class: 'form-select' }
  end
end
