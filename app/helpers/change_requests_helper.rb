# frozen_string_literal: true

module ChangeRequestsHelper
  def change_request_success_message
    url = link_to 'details', @issue['url'], target: '_blank', class: 'alert-link'
    "Your change request was successfully submitted! View the #{url} on GitHub.".html_safe
  end

  def change_request_alert_context
    flash.notice.present? ? 'alert-success' : 'alert-danger'
  end

  def add_synonym_button
    return unless change_requests_enabled?(@ontology.acronym)

    link_to(change_requests_create_synonym_path(concept_id: @concept.id, concept_label: @concept.prefLabel,
                                                ont_acronym: @ontology.acronym),
            role: 'button',
            class: 'btn btn-link',
            aria: { label: 'Create synonym' },
            data: { toggle: 'modal', target: '#changeRequestModal' },
            remote: 'true') do
      content_tag(:i, '', class: 'fas fa-plus-circle fa-lg', aria: { hidden: 'true' }).html_safe
    end
  end

  def remove_synonym_button
    return unless change_requests_enabled?(@ontology.acronym)

    if @concept.synonym.blank?
      tag.a role: 'button', class: 'btn btn-link disabled', aria: { disabled: true } do
        tag.i class: 'fas fa-minus-circle fa-lg', aria: { hidden: true }
      end
    else
      link_to(change_requests_remove_synonym_path(concept_id: @concept.id, concept_label: @concept.prefLabel,
                                                  ont_acronym: @ontology.acronym, concept_synonyms: @concept.synonym),
              role: 'button', class: 'btn btn-link', aria: { label: 'Remove synonym' },
              data: { toggle: 'modal', target: '#changeRequestModal' }, remote: 'true') do
        tag.i class: 'fas fa-minus-circle fa-lg', aria: { hidden: 'true' }
      end
    end
  end

  def synonym_qualifier_select(form)
    options = [%w[exact exact], %w[narrow narrow], %w[broad broad], %w[related related]]
    form.select :qualifier, options_for_select(options, 0), {}, { class: 'form-control' }
  end
end
