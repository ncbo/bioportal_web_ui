module MetadataHelper
  def input_type?(attr, type)
    attr["enforce"].include?(type)
  end

  def submission_metadata
    @metadata ||= Rails.cache.fetch('submission_metadata') do
      JSON.parse(LinkedData::Client::HTTP.get("/submission_metadata", {}, {raw: true}))
    end
  end

  def attr_metadata(attr_key)
    submission_metadata.select { |attr_hash| attr_hash["attribute"].to_s.eql?(attr_key) }.first
  end

  def integer?(attr_label)
    input_type?(attr_metadata(attr_label), 'integer')
  end

  def date_time?(attr_label)
    input_type?(attr_metadata(attr_label), 'date_time')
  end

  def textarea?(attr_label)
    input_type?(attr_metadata(attr_label), 'textarea')
  end

  def enforce_values?(attr)
    !attr["enforcedValues"].nil?
  end

  def list?(attr_label)
    input_type?(attr_metadata(attr_label), "list")
  end

  def isOntology?(attr_label)
    input_type?(attr_metadata(attr_label), 'isOntology')
  end


  def metadata_categories
    submission_metadata.group_by{|x| x['category']}.transform_values{|x| x.map{|attr| attr['attribute']} }
  end
  def ontology_relation?(attr_label)
    relations_attr = metadata_categories['relations']
    !attr_label.to_s.eql?('hasPriorVersion') && relations_attr.include?(attr_label.to_s)
  end

  def open_to_add_metadata?(attr_key)
    attrs = [:naturalLanguage, :hasLicense, :usedOntologyEngineeringTool,
             :accrualPeriodicity, :includedInDataCatalog, :metadataVoc]
    attrs = attrs +  metadata_categories['relations'].map(&:to_sym).reject{|x| x.eql?(:hasPriorVersion)}
    attrs = attrs +  metadata_categories['object description properties'].map(&:to_sym)
    attrs.include?(attr_key.to_sym)
  end

  def content_metadata_attributes(all_metadata = submission_metadata)
    metadata_list = {}
    # Get extracted metadata and put them in a hash with their label, if one, as value
    all_metadata.each do |metadata|
      metadata_list[metadata["attribute"]] = metadata["label"]
    end
    reject = [:description,:csvDump, :dataDump, :openSearchDescription, :metrics, :prefLabelProperty, :definitionProperty,
              :definitionProperty, :synonymProperty, :authorProperty, :hierarchyProperty, :obsoleteProperty,
              :ontology, :endpoint, :submissionId, :submissionStatus, :uploadFilePath, :diffFilePath,
              :pullLocation, :status, :hasOntologyLanguage, :uriLookupEndpoint]
    metadata_list.reject{|k,v| reject.include?(k.to_sym)}.sort_by{|k,v| v || k}
  end

  def attr_uri?(attr_label)
    input_type?(attr_metadata(attr_label), "uri")
  end

  def boolean?(attr_label)
    input_type?(attr_metadata(attr_label), "boolean")
  end


  def display_contact(contacts)
    contacts.map do |c|
      next unless c.member?(:name) && c.member?(:email)

      formatted_name = c[:name].titleize
      formatted_email = c[:email].downcase
      "<div><span class='date_creation_text'>#{formatted_name}</span> (#{formatted_email})</div>"
    end.join("")
  end

  def display_attribute(metadata, value)
    return 'N/A' if value.nil? || Array(value).empty?

    if metadata.eql?("naturalLanguage")
      render LanguageFieldComponent.new(value: value, auto_label: true)
    elsif metadata.to_s.eql?("hasLicense")
      render LicenseFieldComponent.new(value: value)
    elsif date_time?(metadata)
      render DateTimeFieldComponent.new(value: value)
    elsif attr_uri?(metadata)
      render LinkFieldComponent.new(value: value)
    elsif input_type?(attr_metadata(metadata), 'contact')
      display_contact([value]).html_safe
    else
      render TextAreaFieldComponent.new(value: value.to_s)
    end
  end

end