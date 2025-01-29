module InternationalisationHelper

  # Implement logic to make the term 'ontology' configurable throughout the portal,
  # allowing it to be replaced with the variable $RESOURCE_TERM
  def self.t(*args, **kwargs)
    return I18n.t(*args, **kwargs) unless $RESOURCE_TERM

    begin
      original_translation = I18n.t(*args, **kwargs)
      downcase_translation = original_translation.downcase
    rescue StandardError => e
      return e.message
    end

    term = I18n.t("resource_term.ontology")
    plural_term = I18n.t("resource_term.ontology_plural")
    single_term = I18n.t("resource_term.ontology_single")
    resource = I18n.t("resource_term.#{$RESOURCE_TERM}")
    resources = I18n.t("resource_term.#{$RESOURCE_TERM}_plural")
    a_resource = I18n.t("resource_term.#{$RESOURCE_TERM}_single")

    if downcase_translation.include?(term) && resource
      replacement = resource.capitalize
      replacement = resource if downcase_translation.include?(term)
      if downcase_translation.include?(single_term)
        term = single_term
        replacement = a_resource
      end
      original_translation.gsub(term, replacement)
    elsif downcase_translation.include?(plural_term) && resources
      replacement = resources.capitalize
      replacement = resources if downcase_translation.include?(plural_term)
      original_translation.gsub(plural_term, replacement)
    else
      I18n.t(*args, **kwargs)
    end
  end

  # def t(*args, **kwargs)
  #   InternationalisationHelper.t(*args, **kwargs)
  # end

end
