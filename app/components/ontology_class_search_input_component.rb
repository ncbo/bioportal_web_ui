# frozen_string_literal: true

class OntologyClassSearchInputComponent < ViewComponent::Base
  def initialize(ontology_acronym:, name_prefix:, values: [], multiple: true)
    @ontology_acronym = ontology_acronym
    @name_prefix = name_prefix
    @values = values
    @multiple = multiple
  end

  def row_class
    "nested-#{@name_prefix.parameterize}-form-input-row"
  end

  def multiple?
    @multiple
  end
end
