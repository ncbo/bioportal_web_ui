module KnowledgeGraphsHelper
  def kg_list(values)
    Array(values).compact.join(", ")
  end

  def kg_date(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s).strftime("%Y-%m-%d")
  rescue ArgumentError, TypeError
    value
  end

  def kg_link(url, label = nil)
    return nil if url.blank?

    link_to(label || url, url, target: "_blank", rel: "noopener")
  end

  def kg_contact_value(contact_type, value)
    return nil if value.blank?

    case contact_type.to_s.downcase
    when "email"
      mail_to value
    when "url", "homepage", "website"
      kg_link(value)
    when "github"
      kg_link("https://github.com/#{value}", value)
    when "orcid"
      kg_link("https://orcid.org/#{value}", value)
    else
      value
    end
  end
end
