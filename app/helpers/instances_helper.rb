module InstancesHelper
  include ConceptsHelper
  include ApplicationHelper
  def get_instances_by_class_json(concept, query_parameters)
    concept.explore.instances(query_parameters)
  end

  def get_instances_by_ontology_json(ontology, query_parameters)
    ontology.explore.instances(query_parameters)
  end

  def get_instance_details_json(ontology_acronym, instance_uri , query_parameters, raw: false)
    LinkedData::Client::HTTP
      .get("/ontologies/#{ontology_acronym}/instances/#{CGI.escape(instance_uri)}",
           query_parameters, raw: raw)
  end

  def get_instance_and_type(instance_id)
    if instance_id.nil?
      [{}, nil]
    else
      instance_details = JSON.parse(get_instance_details_json(@ontology.acronym,instance_id, {}, raw: true))
      if(!instance_details['types'].nil?)
        types = instance_details['types'].reject{ |type| type.eql? 'http://www.w3.org/2002/07/owl#NamedIndividual'}
        [instance_details, types[0]]
      else
        [{}, nil]
      end
    end
  end

  def instance_label(instance)
    labels = instance['label']
    labels = labels.first if labels.kind_of?(Array)
    labels || instance['prefLabel'] || extract_label_from(instance['@id'])
  end

  def type_of(instance)
    except_types = ['http://www.w3.org/2002/07/owl#NamedIndividual']
    out = instance['types'].filter{ |x| !except_types.include?(x)}
    if !out.empty?
       out.first
    else
       ""
    end
  end

  def link_to_instance(instance, ontology_acronym)
    link_to instance_label(instance),
            ontology_path(ontology_acronym, p: 'classes', conceptid:type_of(instance), instanceid:instance['@id']),
            {target: '_blank'}
  end

  def link_to_class(ontology_acronym, conceptid)
    link_to concept_label(ontology_acronym, conceptid),
            ontology_path(ontology_acronym, p: 'classes', conceptid:conceptid),
            {target: '_blank'}
  end

  def link_to_property(property, ontology_acronym)
    link_to extract_label_from(property),
            ontology_path(ontology_acronym, p: 'properties'),
            { target: '_blank'}
  end

  def instance_property_value(property, ontology_acronym)
    if uri?(property)
      instance, types = get_instance_and_type(property)
      return link_to_instance instance, ontology_acronym unless instance.empty?
    end
    property
  end

  def add_labels_to_print(instance, ontology_acronym)
    instance['labelToPrint'] = instance_label(instance)
    instance['types'].map!{ |t|  {type:t, labelToPrint:concept_label(ontology_acronym , t)}}
    instance
  end

end
