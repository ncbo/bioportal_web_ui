# frozen_string_literal: true

module UsersHelper
  def custom_ontology_set_intro_text
    tag.div do
      concat(tag.p do
        concat(tag.span('Customize your display: ', class: 'fw-bold text-muted'))
        concat(tag.span("pick the ontologies you want to see and #{$SITE} will hide all other ontologies.",
                        class: 'text-muted'))
      end)
      concat(tag.p('Please note: you must be logged in to use this feature', class: 'fst-italic text-muted'))
    end
  end

  def custom_ontology_set_slice_text
    tag.p class: 'mb-5' do
      concat('Please visit the ')
      concat(link_to('main site', "#{$UI_URL}/account"))
      concat(' to modify your custom ontology set')
    end
  end
end
