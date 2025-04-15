var
  bp_last_params = null,
  annotationsTable = null,
  annotator_ontologies = null;

// Note: the configuration is in config/bioportal_config.rb.
var BP_CONFIG = jQuery(document).data().bp.config;

var BP_COLUMNS = {
  classes: 0,
  ontologies: 1,
  types: 2,
  sem_types: 3,
  matched_classes: 5,
  matched_ontologies: 6
};

var CONCEPT_MAP = {
  "mapping": "mappedConcept",
  "mgrep": "concept",
  "closure": "concept"
};

function set_last_params(params) {
  bp_last_params = params;
  bp_last_params.apikey = BP_CONFIG.apikey; // TODO: get the user apikey?
  //console.log(bp_last_params);
}

function insertSampleText(event) {
  "use strict";
  event.preventDefault();
  var text = "Melanoma is a malignant tumor of melanocytes which are found predominantly in skin but also in the bowel and the eye.";
  jQuery("#annotation_text").focus();
  jQuery("#annotation_text").val(text);
}

function get_annotations() {
  jQuery("#results_error").html("");
  jQuery("#annotator_error").html("");

  // Validation
  if (!jQuery("#annotation_text").val()) {
    jQuery("#annotator_error").html("Please enter text to annotate");
    return;
  }

  // Really dumb, basic word counter.
  if (jQuery("#annotation_text").val().split(' ').length > 500) {
    jQuery("#annotator_error").html("Please use less than 500 words. If you need to annotate larger pieces of text you can use the <a href='http://www.bioontology.org/wiki/index.php/Annotator_User_Guide' target='_blank'>Annotator Web Service</a>");
    return;
  }

  jQuery("#annotations_container").hide();
  jQuery(".annotator_spinner").show();
  ajax_process_halt();

  var params = {},
    ont_select = jQuery("#ontology_ontologyId"),
    mappings = [];

  params.text = jQuery("#annotation_text").val();
  params.ontologies = (ont_select.val() === null) ? [] : ont_select.val();
  params.longest_only = jQuery("#longest_only").is(':checked');
  params.exclude_numbers = jQuery("#exclude_numbers").is(':checked');
  params.whole_word_only = !jQuery("#match_partial_words").is(':checked');
  params.exclude_synonyms = jQuery("#exclude_synonyms").is(':checked');
  params.ncbo_slice = (("ncbo_slice" in BP_CONFIG) ? BP_CONFIG.ncbo_slice : '');

  var maxLevel = parseInt(jQuery("#class_hierarchy_max_level").val());
  if (maxLevel > 0) {
    params.expand_class_hierarchy = "true";
    params.class_hierarchy_max_level = maxLevel.toString();
  }

  // UI checkbox to control using the batch call in the controller.
  params.raw = true; // do not use batch call to resolve class prefLabel and ontology names.
  //if( jQuery("#use_ajax").length > 0 ) {
  //  params.raw = jQuery("#use_ajax").is(':checked');
  //}

  // Use the annotator default for wholeWordOnly = true.
  //if (jQuery("#wholeWordOnly:checked").val() !== undefined) {
  //  params.wholeWordOnly = jQuery("#wholeWordOnly:checked").val();
  //}

  jQuery("[name='mappings']:checked").each(function() {
    mappings.push(jQuery(this).val());
  });
  params.mappings = mappings;

  if (jQuery("#semantic_types").val() !== null) {
    params.semantic_types = jQuery("#semantic_types").val();
    annotationsTable.fnSetColumnVis(BP_COLUMNS.sem_types, true);
    jQuery("#results_error").html("Only results from ontologies with semantic types available are displayed.");
  } else {
    annotationsTable.fnSetColumnVis(BP_COLUMNS.sem_types, false);
  }

  params["recognizer"] = jQuery("#recognizer").val();

  jQuery.ajax({
    type: "POST",
    url: "/annotator", // Call back to the UI annotation_controller::create method
    data: params,
    dataType: "json",
    success: function(data) {
      set_last_params(params);
      display_annotations(data, bp_last_params);
      jQuery(".annotator_spinner").hide(200);
      jQuery("#annotations_container").show(300);
    },
    error: function(data) {
      set_last_params(params);
      jQuery(".annotator_spinner").hide(200);
      jQuery("#annotations_container").hide();
      jQuery("#annotator_error").html(" Problem getting annotations, please try again");
    }
  });
} // get_annotations

var displayFilteredColumnNames = function() {
  "use strict";
  var column_names = [];
  var header_text;
  jQuery(".bp_popup_list input:checked").closest("th").each(function() {
    header_text = this.childNodes[0].textContent.trim();
    column_names.push(header_text);
  });
  jQuery("#filter_names").html(column_names.join(", "));
  if (column_names.length > 0) {
    jQuery("#filter_list").show();
  } else {
    jQuery("#filter_list").hide();
  }
};

function createFilterCheckboxes(filter_items, checkbox_class, checkbox_location) {
  "use strict";
  var for_sort = [],
    sorted = [];

  // Sort ontologies by number of results
  jQuery.each(filter_items, function(k, v) {
    for_sort.push({
      label: k + " (" + v + ")",
      count: v,
      value: k,
      value_encoded: encodeURIComponent(k)
    });
  });
  for_sort.sort(function(a, b) {
    return jQuery.trim(a.label) > jQuery.trim(b.label)
  });

  // Create checkboxes for ontology filter
  jQuery.each(for_sort, function() {
    var checkbox = jQuery("<input/>").attr("class", checkbox_class).attr("type", "checkbox").attr("value", this.value).attr("id", checkbox_class + this.value_encoded);
    var label = jQuery("<label/>").attr("for", checkbox_class + this.value_encoded).html(" " + this.label);
    sorted.push(jQuery("<span/>").append(checkbox).append(label).html());
  });
  jQuery("#" + checkbox_location).html(sorted.join("<br/>"));
}

var filter_ontologies = {
  init: function() {
    "use strict";
    jQuery("#filter_ontologies").bind("click", function(e) {
      bp_popup_init(e)
    });
    // Need to use bind to avoid "live" propogation issues
    jQuery(".filter_ontology_checkboxes").bind("click", function(e) {
      filter_ontologies.filterOntology(e)
    });
    jQuery("#ontology_filter_list").click(function(e) {
      e.stopPropagation()
    });
    this.cleanup();
  },

  cleanup: function() {
    "use strict";
    jQuery("html").click(bp_popup_cleanup);
    jQuery(document).keyup(function(e) {
      if (e.keyCode == 27) {
        bp_popup_cleanup();
      } // esc
    });
  },

  filterOntology: function(e) {
    "use strict";
    e.stopPropagation();
    var search_regex = [];
    jQuery(".filter_ontology_checkboxes:checked").each(function() {
      search_regex.push(jQuery(this).val());
    });
    displayFilteredColumnNames();
    if (search_regex.length === 0) {
      annotationsTable.fnFilter("", BP_COLUMNS.ontologies);
    } else {
      annotationsTable.fnFilter(search_regex.join("|"), BP_COLUMNS.ontologies, true, false);
    }
  }
};

var filter_classes = {
  init: function() {
    "use strict";
    jQuery("#filter_classes").bind("click", function(e) {
      bp_popup_init(e)
    });
    // Need to use bind to avoid "live" propogation issues
    jQuery(".filter_classes_checkboxes").bind("click", function(e) {
      filter_classes.filterClasses(e)
    });
    jQuery("#classes_filter_list").click(function(e) {
      e.stopPropagation()
    });
    this.cleanup();
  },

  cleanup: function() {
    "use strict";
    jQuery("html").click(bp_popup_cleanup);
    jQuery(document).keyup(function(e) {
      if (e.keyCode == 27) {
        bp_popup_cleanup();
      } // esc
    });
  },

  filterClasses: function(e) {
    "use strict";
    e.stopPropagation();
    var search_regex = [];
    jQuery(".filter_classes_checkboxes:checked").each(function() {
      // Escape characters used in regex
      search_regex.push(jQuery(this).val().replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"));
    });
    displayFilteredColumnNames();
    if (search_regex.length === 0) {
      annotationsTable.fnFilter("", BP_COLUMNS.classes);
    } else {
      annotationsTable.fnFilter("^" + search_regex.join("(?!.)|^") + "(?!.)", BP_COLUMNS.classes, true, false);
    }
  }
};

var filter_matched_ontologies = {
  init: function() {
    "use strict";
    jQuery("#filter_matched_ontologies").bind("click", function(e) {
      bp_popup_init(e);
    });
    // Need to use bind to avoid "live" propogation issues
    jQuery(".filter_matched_ontology_checkboxes").bind("click", function(e) {
      filter_matched_ontologies.filter(e);
    });
    jQuery("#ontology_matched_filter_list").click(function(e) {
      e.stopPropagation();
    });
    this.cleanup();
  },

  cleanup: function() {
    "use strict";
    jQuery("html").click(bp_popup_cleanup);
    jQuery(document).keyup(function(e) {
      if (e.keyCode == 27) {
        bp_popup_cleanup();
      } // esc
    });
  },

  filter: function(e) {
    "use strict";
    e.stopPropagation();
    var search_regex = [];
    jQuery(".filter_matched_ontology_checkboxes:checked").each(function() {
      search_regex.push(jQuery(this).val());
    });
    displayFilteredColumnNames();
    if (search_regex.length === 0) {
      annotationsTable.fnFilter("", BP_COLUMNS.matched_ontologies);
    } else {
      annotationsTable.fnFilter(search_regex.join("|"), BP_COLUMNS.matched_ontologies, true, false);
    }
  }
};

var filter_matched_classes = {
  init: function() {
    "use strict";
    jQuery("#filter_matched_classes").bind("click", function(e) {
      bp_popup_init(e)
    });
    // Need to use bind to avoid "live" propogation issues
    jQuery(".filter_matched_classes_checkboxes").bind("click", function(e) {
      filter_matched_classes.filter(e)
    });
    jQuery("#matched_classes_filter_list").click(function(e) {
      e.stopPropagation()
    });
    this.cleanup();
  },

  cleanup: function() {
    "use strict";
    jQuery("html").click(bp_popup_cleanup);
    jQuery(document).keyup(function(e) {
      if (e.keyCode == 27) {
        bp_popup_cleanup();
      } // esc
    });
  },

  filter: function(e) {
    "use strict";
    e.stopPropagation();
    var search_regex = [];
    jQuery(".filter_matched_classes_checkboxes:checked").each(function() {
      // Escape characters used in regex
      search_regex.push(jQuery(this).val().replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"));
    });
    displayFilteredColumnNames();
    if (search_regex.length === 0) {
      annotationsTable.fnFilter("", BP_COLUMNS.matched_classes);
    } else {
      annotationsTable.fnFilter("^" + search_regex.join("(?!.)|^") + "(?!.)", BP_COLUMNS.matched_classes, true, false);
    }
  }
};

var filter_match_type = {
  init: function() {
    "use strict";
    jQuery("#filter_match_type").bind("click", function(e) {
      bp_popup_init(e)
    });
    // Need to use bind to avoid "live" propogation issues
    jQuery(".filter_match_type_checkboxes").bind("click", function(e) {
      filter_match_type.filterMatchType(e)
    });
    jQuery("#match_type_filter_list").click(function(e) {
      e.stopPropagation()
    });
    this.cleanup();
  },

  cleanup: function() {
    "use strict";
    jQuery("html").click(bp_popup_cleanup);
    jQuery(document).keyup(function(e) {
      if (e.keyCode == 27) {
        bp_popup_cleanup();
      } // esc
    });
  },

  filterMatchType: function(e) {
    "use strict";
    e.stopPropagation();
    var search_regex = [];
    jQuery(".filter_match_type_checkboxes:checked").each(function() {
      // Escape characters used in regex
      search_regex.push(jQuery(this).val().replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"));
    });
    displayFilteredColumnNames();
    if (search_regex.length === 0) {
      annotationsTable.fnFilter("", BP_COLUMNS.types);
    } else {
      annotationsTable.fnFilter("^" + search_regex.join("(?!.)|^") + "(?!.)", BP_COLUMNS.types, true, false);
    }
  }
};

var removeFilters = function() {
  "use strict";
  jQuery(".filter_ontology_checkboxes").attr("checked", false);
  jQuery(".filter_classes_checkboxes").attr("checked", false);
  jQuery(".filter_match_type_checkboxes").attr("checked", false);
  jQuery(".filter_matched_classes_checkboxes").attr("checked", false);
  jQuery(".filter_matched_ontologies_checkboxes").attr("checked", false);
  annotationsTable.fnFilter("", BP_COLUMNS.classes);
  annotationsTable.fnFilter("", BP_COLUMNS.ontologies);
  annotationsTable.fnFilter("", BP_COLUMNS.types);
  annotationsTable.fnFilter("", BP_COLUMNS.matched_classes);
  annotationsTable.fnFilter("", BP_COLUMNS.matched_ontologies);
  jQuery("#filter_list").hide();
};

// Datatables reset sort extension
jQuery.fn.dataTableExt.oApi.fnSortNeutral = function(oSettings) {
  "use strict";
  /* Remove any current sorting */
  oSettings.aaSorting = [];
  /* Sort display arrays so we get them in numerical order */
  oSettings.aiDisplay.sort(function(x, y) {
    return x - y;
  });
  oSettings.aiDisplayMaster.sort(function(x, y) {
    return x - y;
  });
  /* Redraw */
  oSettings.oApi._fnReDraw(oSettings);
};


function annotatorFormatLink(param_string, format) {
  "use strict";
  // TODO: Check whether 'text' and 'tabDelimited' could work.
  // For now, assume that json and xml will work or should work.
  var format_map = {
    "json": "JSON",
    "xml": "XML",
    "text": "Text",
    "tabDelimited": "CSV"
  };
  var query = BP_CONFIG.rest_url + "/annotator?apikey=" + BP_CONFIG.apikey + "&" + param_string;
  if (format !== 'json') {
    query += "&format=" + format;
  }
  var link = "<a href=\"" + encodeURI(query) + "\" target=\"_blank\">" + format_map[format] + "</a>";
  jQuery("#download_links_" + format.toLowerCase()).html(link);
}

function generateParameters() {
  "use strict";
  var params = [];
  var new_params = jQuery.extend(true, {}, bp_last_params); // deep copy
  delete new_params["apikey"];
  delete new_params["format"];
  delete new_params["raw"];
  //console.log(new_params);
  jQuery.each(new_params, function(k, v) {
    if (v !== null && v !== undefined) {
      if (typeof v == "boolean") {
        params.push(k + "=" + v);
      } else if (typeof v == "string" && v.length > 0) {
        params.push(k + "=" + v);
      } else if (typeof v == "array" && v.length > 0) {
        params.push(k + "=" + v.join(','));
      } else if (typeof v == "object" && v.length > 0) {
        params.push(k + "=" + v.join(','));
      }
    }
  });
  return params.join("&");
}

jQuery(document).ready(function() {
  "use strict";
  jQuery("#annotator_button").click(get_annotations);
  jQuery("#semantic_types").chosen({
    search_contains: true
  });
  jQuery("#insert_text_link").click(insertSampleText);
  // Init annotation table
  annotationsTable = jQuery("#annotations").dataTable({
    bPaginate: false,
    bAutoWidth: false,
    aaSorting: [],
    oLanguage: {
      sZeroRecords: "No annotations found"
    },
    "aoColumns": [{
      "sWidth": "15%"
    }, {
      "sWidth": "15%"
    }, {
      "sWidth": "5%"
    }, {
      "sWidth": "5%",
      "bVisible": false
    }, {
      "sWidth": "30%"
    }, {
      "sWidth": "15%"
    }, {
      "sWidth": "15%"
    }]
  });
  filter_ontologies.init();
  filter_classes.init();
  filter_match_type.init();
  filter_matched_ontologies.init();
  filter_matched_classes.init();

  jQuery("#annotations_container").hide();
}); // doc ready


function get_link(uri, label) {
  "use strict";
  return '<a href="' + uri + '">' + label + '</a>';
}

function get_class_details(cls) {
  var
    cls_rel_ui = cls.ui.replace(/^.*\/\/[^\/]+/, ''),
    ont_rel_ui = cls_rel_ui.replace(/\?p=classes.*$/, '?p=summary');
  return class_details = {
    cls_rel_ui: cls_rel_ui,
    ont_rel_ui: ont_rel_ui,
    cls_link: get_link(cls_rel_ui, cls.prefLabel),
    ont_link: get_link(ont_rel_ui, cls.ontology.name),
    semantic_types: cls.semantic_types.join('; ') // test with 'abscess' text and sem type = T046,T020
  }
}

function get_class_details_from_raw(cls) {
  var
    ont_acronym = cls.links.ontology.replace(/.*\//, ''),
    ont_name = annotator_ontologies[cls.links.ontology].name,
    ont_rel_ui = '/ontologies/' + ont_acronym,
    ont_link = null;
  if (ont_name === undefined) {
    ont_link = get_link_for_ont_ajax(ont_acronym);
  } else {
    ont_link = get_link(ont_rel_ui, ont_name); // no ajax required!
  }
  var
    cls_rel_ui = cls.links.ui.replace(/^.*\/\/[^\/]+/, ''),
    cls_label = cls.prefLabel,
    cls_link = null;
  if (cls_label === undefined) {
    cls_link = get_link_for_cls_ajax(cls['@id'], ont_acronym);
  } else {
    cls_link = get_link(cls_rel_ui, cls_label); // no ajax required!
  }
  return class_details = {
    cls_rel_ui: cls_rel_ui,
    ont_rel_ui: ont_rel_ui,
    cls_link: cls_link,
    ont_link: ont_link,
    //
    // TODO: Get semantic types from raw data, currently provided by controller.
    //semantic_types: cls.semantic_types.join('; ') // test with 'abscess' text and sem type = T046,T020
    semantic_types: ''
  }
}

function get_text_markup(text, from, to) {
  var
    text_match = text.substring(from - 1, to),
    // remove everything prior to the preceding three words (using space delimiters):
    text_prefix = text.substring(0, from - 1).replace(/.* ((?:[^ ]* ){2}[^ ]*$)/, "... $1"),
    // remove the fourth space and everything following it
    text_suffix = text.substring(to).replace(/^((?:[^ ]* ){3}[^ ]*) [\S\s]*/, "$1 ..."),
    match_span = '<span style="color: rgb(153,153,153);">',
    match_markup_span = '<span style="color: rgb(35, 73, 121); font-weight: bold; padding: 2px 0px;">',
    text_markup = match_markup_span + text_match + "</span>";
  //console.log('text markup: ' + text_markup);
  return match_span + text_prefix + text_markup + text_suffix + "</span>";
}

function get_annotation_rows(annotation, params) {
  "use strict";
  // data independent var declarations
  var
    rows = [],
    cells = [],
    text_markup = '',
    match_type = '',
    match_type_translation = {
      "mgrep": "direct",
      "mapping": "mapping",
      "closure": "ancestor"
    };
  // data dependent var declarations
  var cls = get_class_details(annotation.annotatedClass);
  jQuery.each(annotation.annotations, function(i, a) {
    text_markup = get_text_markup(params.text, a.from, a.to);
    match_type = match_type_translation[a.matchType.toLowerCase()] || 'direct';
    cells = [cls.cls_link, cls.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
    rows.push(cells);
    // Add rows for any classes in the hierarchy.
    match_type = 'ancestor';
    var h_c = null;
    jQuery.each(annotation.hierarchy, function(i, h) {
      h_c = get_class_details(h.annotatedClass);
      cells = [h_c.cls_link, h_c.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
      rows.push(cells);
    }); // hierarchy loop
    // Add rows for any classes in the mappings. Note the ont_link will be different.
    match_type = 'mapping';
    var m_c = null;
    jQuery.each(annotation.mappings, function(i, m) {
      m_c = get_class_details(m.annotatedClass);
      cells = [m_c.cls_link, m_c.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
      rows.push(cells);
    }); // mappings loop
  }); // annotations loop
  return rows;
}

function get_annotation_rows_from_raw(annotation, params) {
  "use strict";
  // data independent var declarations
  var
    rows = [],
    cells = [],
    text_markup = '',
    match_type = '',
    match_type_translation = {
      "mgrep": "direct",
      "mapping": "mapping",
      "closure": "ancestor"
    };
  // data dependent var declarations
  var cls = get_class_details_from_raw(annotation.annotatedClass);
  if (annotation.annotations.length == 0) {
    cells = [cls.cls_link, cls.ont_link, "", cls.semantic_types, "", cls.cls_link, cls.ont_link];
    rows.push(cells);
  } else {
    jQuery.each(annotation.annotations, function(i, a) {
      text_markup = get_text_markup(params.text, a.from, a.to);
      match_type = match_type_translation[a.matchType.toLowerCase()] || 'direct';
      cells = [cls.cls_link, cls.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
      rows.push(cells);
      // Add rows for any classes in the hierarchy.
      match_type = 'ancestor';
      var h_c = null;
      jQuery.each(annotation.hierarchy, function(i, h) {
        h_c = get_class_details_from_raw(h.annotatedClass);
        cells = [h_c.cls_link, h_c.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
        rows.push(cells);
      }); // hierarchy loop
      // Add rows for any classes in the mappings. Note the ont_link will be different.
      match_type = 'mapping';
      var m_c = null;
      jQuery.each(annotation.mappings, function(i, m) {
        m_c = get_class_details_from_raw(m.annotatedClass);
        cells = [m_c.cls_link, m_c.ont_link, match_type, cls.semantic_types, text_markup, cls.cls_link, cls.ont_link];
        rows.push(cells);
      }); // mappings loop
    }); // annotations loop
  }
  return rows;
}


function update_annotations_table(rowsArray) {
  "use strict";
  var ontologies = {},
    classes = {},
    match_types = {},
    matched_ontologies = {},
    matched_classes = {},
    context_count = 0;

  jQuery(rowsArray).each(function() {
    // [ cls_link, ont_link, match_type, semantic_types, text_markup, cls_link, ont_link ];
    var row = this,
      cls_link = row[0],
      ont_link = row[1],
      match_type = row[2], // direct, ancestors, mapping
      //semantic_type = row[3],
      //match_text = row[4],
      match_cls_link = row[5],
      match_ont_link = row[6];
    // Extract labels from links (using non-greedy regex).
    var cls_label = cls_link.replace(/^<a.*?>/, '').replace('</a>', '').toLowerCase(),
      ont_label = ont_link.replace(/^<a.*?>/, '').replace('</a>', ''),
      match_cls_label = match_cls_link.replace(/^<a.*?>/, '').replace('</a>', '').toLowerCase(),
      match_ont_label = match_ont_link.replace(/^<a.*?>/, '').replace('</a>', '');

    // TODO: Gather sem types for display
    //    var semantic_types = [];
    //    jQuery.each(annotation.concept.semantic_types, function () {
    //      semantic_types.push(this.description);
    //    });

    // Keep track of contexts. If there are none (IE when using mallet), hide the column
    if (row[4] !== "") context_count++;

    // Keep track of how many results are associated with each ontology
    ontologies[ont_label] = (ont_label in ontologies) ? ontologies[ont_label] + 1 : 1;
    // Keep track of how many results are associated with each class
    classes[cls_label] = (cls_label in classes) ? classes[cls_label] + 1 : 1;
    // Keep track of match types
    match_types[match_type] = (match_type in match_types) ? match_types[match_type] + 1 : 1;
    // Keep track of matched classes
    matched_classes[match_cls_label] = (match_cls_label in matched_classes) ? matched_classes[match_cls_label] + 1 : 1;
    // Keep track of matched ontologies
    matched_ontologies[match_ont_label] = (match_ont_label in matched_ontologies) ? matched_ontologies[match_ont_label] + 1 : 1;
  });

  // Add result counts
  var count_span = '<span class="result_count">'
  jQuery("#result_counts").html("total results " + count_span + rowsArray.length + "</span>&nbsp;");
  var direct_count = ("direct" in match_types) ? match_types["direct"] : 0,
    ancestor_count = ("ancestor" in match_types) ? match_types["ancestor"] : 0,
    mapping_count = ("mapping" in match_types) ? match_types["mapping"] : 0;
  jQuery("#result_counts").append("(");
  jQuery("#result_counts").append("direct " + count_span + direct_count + "</span>");
  jQuery("#result_counts").append("&nbsp;/&nbsp;" + "ancestor " + count_span + ancestor_count + "</span>");
  jQuery("#result_counts").append("&nbsp;/&nbsp;" + "mapping " + count_span + mapping_count + "</span>");
  jQuery("#result_counts").append(")");

  // Add checkboxes to filters
  createFilterCheckboxes(ontologies, "filter_ontology_checkboxes", "ontology_filter_list");
  createFilterCheckboxes(classes, "filter_classes_checkboxes", "classes_filter_list");
  createFilterCheckboxes(match_types, "filter_match_type_checkboxes", "match_type_filter_list");
  createFilterCheckboxes(matched_ontologies, "filter_matched_ontology_checkboxes", "matched_ontology_filter_list");
  createFilterCheckboxes(matched_classes, "filter_matched_classes_checkboxes", "matched_classes_filter_list");

  // Reset table
  annotationsTable.fnClearTable();
  annotationsTable.fnSortNeutral();
  removeFilters();

  // Need to re-init because we're not using "live" because of propagation issues
  filter_ontologies.init();
  filter_classes.init();
  filter_match_type.init();
  filter_matched_ontologies.init();
  filter_matched_classes.init();

  // Add data
  if (rowsArray.length > 0) {
    annotationsTable.fnAddData(rowsArray);
  }

  // Hide columns as necessary
  if (context_count == 0) {
    annotationsTable.fnSetColumnVis(4, false);
  } else {
    annotationsTable.fnSetColumnVis(4, true);
  }

  var match_keys = Object.keys(match_types);
  if (match_keys.length == 1 && match_keys[0] === "")
    annotationsTable.fnSetColumnVis(2, false);
}


function display_annotations(data, params) {
  "use strict";
  var annotations = data.annotations;
  var all_rows = [];
  if (params.raw !== undefined && params.raw === true) {
    // The annotator_controller does not 'massage' the REST data.
    // The class prefLabel and ontology name must be resolved with ajax.
    annotator_ontologies = data.ontologies;
    for (var i = 0; i < annotations.length; i++) {
      all_rows = all_rows.concat(get_annotation_rows_from_raw(annotations[i], params));
    }
  } else {
    // The annotator_controller does 'massage' the REST data.
    // The class prefLabel and ontology name get resoled with a batch all in the controller.
    for (var i = 0; i < annotations.length; i++) {
      all_rows = all_rows.concat(get_annotation_rows(annotations[i], params));
    }
  }
  update_annotations_table(all_rows);
  // Generate parameters for list at bottom of page
  var param_string = generateParameters(); // uses bp_last_param
  var query = BP_CONFIG.rest_url + "/annotator?" + param_string;
  var query_encoded = BP_CONFIG.rest_url + "/annotator?" + encodeURIComponent(param_string);
  jQuery("#annotator_parameters").html(query);
  jQuery("#annotator_parameters_encoded").html(query_encoded);
  // Add links for downloading results
  //annotatorFormatLink("tabDelimited");
  annotatorFormatLink(param_string, "json");
  annotatorFormatLink(param_string, "xml");
  if (params.raw !== undefined && params.raw === true) {
    // Initiate ajax calls to resolve class ID to prefLabel and ontology acronym to name.
    ajax_process_init(); // see bp_ajax_controller.js
  }
}



// Creates an HTML form with a button that will POST to the annotator
//function annotatorPostForm(format) {
//  "use strict";
//  // TODO: Check whether 'text' and 'tabDelimited' could work.
//  // For now, assume that json and xml will work or should work.
//  var format_map = { "json": "JSON", "xml": "XML", "text": "Text", "tabDelimited": "CSV" };
//  var params = bp_last_params;
//  params["format"] = format;
//  var form_fields = [];
//  jQuery.each(params, function (k, v) {
//    if (v != null) {
//      form_fields.push("<input type='hidden' name='" + k + "' value='" + v + "'>");
//    }
//  });
//  var action = "action='" + BP_CONFIG.rest_url + "/annotator'";
//  var form = jQuery("<form " + action + " method='post' target='_blank'/>")
//    .append(form_fields.join(""))
//    .append("<input type='submit' value='" + format_map[format] + "'>");
//  jQuery("#download_links_" + format.toLowerCase()).html(form);
//}
