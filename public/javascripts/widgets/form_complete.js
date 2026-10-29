// ***********************************
// Widget-specific code
// ***********************************

// Set a variable to check to see if this script is loaded
var BP_FORM_COMPLETE_LOADED = true;

// Set the defaults if they haven't been set yet
if (typeof BP_SEARCH_SERVER === 'undefined') {
  var BP_SEARCH_SERVER = "http://bioportal.bioontology.org";
}
if (typeof BP_SITE === 'undefined') {
  var BP_SITE = "BioPortal";
}
if (typeof BP_ORG === 'undefined') {
  var BP_ORG = "NCBO";
}
if (typeof BP_ONTOLOGIES === 'undefined') {
  var BP_ONTOLOGIES = "";
}

var BP_ORG_SITE = (BP_ORG == "") ? BP_SITE : BP_ORG + " " + BP_SITE;

function determineHTTPS(url) {
  return url.replace("http:", ('https:' == document.location.protocol ? 'https:' : 'http:'));
}

BP_SEARCH_SERVER = determineHTTPS(BP_SEARCH_SERVER);

var formComplete_searchBoxID = "BP_search_box",
    formComplete_searchBoxSelector = "#" + formComplete_searchBoxID;

function bpFormCompleteOnLoad() {
  jQuery(document).ready(function(){
    formComplete_setup_functions(true);
  });
}

// Formats the search results
function formComplete_formatItem(row) {

    var input = this.extraParams.input;
    var BP_include_definitions = jQuery(input).attr("data-bp_include_definitions");
    if (typeof BP_include_definitions === "undefined") {
      BP_include_definitions = false;
    }

    // Get ontology ID and other parameters
    var ontology_id = null;
    var classes = jQuery(input).attr('class').split(" ");
    jQuery(classes).each(function() {
      if (this.indexOf("bp_form_complete") === 0) {
        var values = this.split("-");
        ontology_id = decodeURIComponent(values[1]);
      }
    });
    if (ontology_id == "all") {
      ontology_id = "";
    }

    // Process match type
    var resultTypeSpan = jQuery("<span>");
    resultTypeSpan.attr("style","font-size:9px;color:blue;");
    if (typeof row[2] !== "undefined" && row[2] !== "") {
        resultTypeSpan.text(row[2]);
    }

    // Process class label, including synonyms
    var specials = new RegExp("[.*+?|()\\[\\]{}\\\\]", "g"), // .*+?|()[]{}\
        keywords = jQuery(input).val().trim().replace(specials, "\\$&").split(' ').join('|'),
        regex = new RegExp('(' + keywords + ')', 'gi');
    // synonyms
    if (row[0].match(regex) == null) {
        var contents = row[6].split("\t");
        var synonym = contents[0] || "";
        synonym = synonym.split(";");
        if (synonym !== "") {
            var matchSynonym = jQuery.grep(synonym, function(e) {
                return e.match(regex) != null;
            });
            row[0] = row[0] + " (synonyms: " + matchSynonym.join(", ") + ")";
        }
    }
    // cleanup obsolete class tag before markup for search keywords.
    if (row[0].indexOf("[obsolete]") != -1) {
        row[0] = row[0].replace("[obsolete]", "");
        obsolete_prefix = "<span class='obsolete_class' title='obsolete class'>";
        obsolete_suffix = "</span>";
    } else {
        obsolete_prefix = "";
        obsolete_suffix = "";
    }
    // Markup the search keywords.
    var resultClass = row[0].replace(regex, "<b><span style='color:#006600;'>$1</span></b>");
    // Set wider class name column
    var resultClassWidth = "350px";
    if (BP_include_definitions) {
        resultClassWidth = "150px";
    } else if (ontology_id == "") {
        resultClassWidth = "320px";
    }
    var resultClassDiv = jQuery("<div>");
    resultClassDiv.addClass("result_class");
    resultClassDiv.attr("style", "width: " + resultClassWidth);
    resultClassDiv.html(resultClass); // resultClass contains markup, not just text.

    // Gather components to construct result <div> element
    var resultDiv = jQuery("<div>");
    // row[7] is the ontology_id, only included when searching multiple ontologies
    var result_ont_version = row[3],
        result_uri = row[4];
    if (ontology_id !== "") {
        if (BP_include_definitions) {
            resultDiv.append(definitionDiv(result_ont_version, result_uri));
        }
        resultDiv.append(resultClassDiv);
        resultDiv.append(resultTypeSpan.attr("style", "overflow: hidden; float: none;"));
    } else {
        resultDiv.append(resultClassDiv);
        if (BP_include_definitions) {
            resultDiv.append(definitionDiv(result_ont_version, result_uri));
        }
        resultDiv.append(resultTypeSpan);
        var resultOnt = row[7];
        var resultOntDiv = jQuery("<div>");
        resultOntDiv.addClass("result_ontology");
        resultOntDiv.attr("style", "overflow: hidden;");
        resultOntDiv.html(truncateText(resultOnt, 30));
        resultDiv.append(resultOntDiv);
    }
    return obsolete_prefix + resultDiv.html() + obsolete_suffix;
}

function definitionDiv(ont, concept) {
    var definitionAjax = jQuery("<a>");
    definitionAjax.addClass("get_definition_via_ajax");
    definitionAjax.attr("href", BP_SEARCH_SERVER + "/ajax/json_class?callback=?&ontologyid=" + ont + "&conceptid=" + encodeURIComponent(concept));
    var definitionDiv = jQuery("<div>");
    definitionDiv.addClass('result_definition');
    definitionDiv.text("retreiving definitions...");
    definitionDiv.append(definitionAjax);
    return definitionDiv;
}

function formComplete_setup_functions(onlyNew) {
  jQuery("input[class*='bp_form_complete']").each(function(){
    if (onlyNew && this.autocompleter) return;
    var classes = this.className.split(" ");
    var values;
    var ontology_id;
    var target_property;

    var BP_search_branch = jQuery(this).attr("data-bp_search_branch");
    if (typeof BP_search_branch === "undefined") {
      BP_search_branch = "";
    }

    var BP_include_definitions = jQuery(this).attr("data-bp_include_definitions");
    if (typeof BP_include_definitions === "undefined") {
      BP_include_definitions = false;
    }

    // Setup polling if we need definitions
    if (BP_include_definitions) {
      getWidgetAjaxContent();
    }

    var BP_objecttypes = jQuery(this).attr("data-bp_objecttypes");
    if (typeof BP_objecttypes === "undefined") {
      BP_objecttypes = "";
    }

    // Find the 'bp_form_complete-{ontologyId,...}-{property}' values
    // in the class attribute(s)
    jQuery(classes).each(function() {
      if (this.indexOf("bp_form_complete") === 0) {
        values = this.split("-");
        ontology_id = decodeURIComponent(values[1]); // Could be CSV (see wiki documentation)
        target_property = values[2];
      }
    });

    if (ontology_id == "all") { // Doesn't handle CSV?
      ontology_id = "";
    }

    var extra_params = {
      input: this,
      target_property: target_property,
      subtreerootconceptid: encodeURIComponent(BP_search_branch),
      objecttypes: BP_objecttypes,
      id: BP_ONTOLOGIES, // not 'ontology_id', see below...
      ontologies: ontology_id
    };

    var result_width = 450;
    // Add space for definition
    if (BP_include_definitions) {
      result_width += 275;
    }
    // Add space for ontology name
    if (ontology_id === "") {
      result_width += 200;
    }

    // see "public/javascripts/JqueryPlugins/autocomplete/crossdomain_autocomplete.js"
    jQuery(this).bioportal_autocomplete(
      BP_SEARCH_SERVER + "/search/json_search/",
      {
          extraParams: extra_params,
          lineSeparator: "~!~",
          matchSubset: 0,
          minChars: 3,
          maxItemsToShow: 20,
          width: result_width,
          onItemSelect: bpFormSelect,
          footer: '<div style="color: grey; font-size: 8pt; font-family: Verdana; padding: .8em .5em .3em;">Results provided by <a style="color: grey;" href="' + BP_SEARCH_SERVER + '">' + BP_ORG_SITE + '</a></div>',
          formatItem: formComplete_formatItem
      }
    );
    // formComplete_searchBox = jQuery(this)[0].autocompleter;

    var html = "";
    if (document.getElementById(jQuery(this).attr('name') + "_bioportal_concept_id") == null)
      html += "<input type='hidden' id='" + jQuery(this).attr('name') + "_bioportal_concept_id'>";
    if (document.getElementById(jQuery(this).attr('name') + "_bioportal_ontology_id") == null)
      html += "<input type='hidden' id='" + jQuery(this).attr('name') + "_bioportal_ontology_id'>";
    if (document.getElementById(jQuery(this).attr('name') + "_bioportal_full_id") == null)
      html += "<input type='hidden' id='" + jQuery(this).attr('name') + "_bioportal_full_id'>";
    if (document.getElementById(jQuery(this).attr('name') + "_bioportal_preferred_name") == null)
      html += "<input type='hidden' id='" + jQuery(this).attr('name') + "_bioportal_preferred_name'>";

    jQuery(this).after(html);
  });
}

// Sets a hidden form value that records the concept id when a concept is chosen in the jump to
// This is a workaround because the default autocomplete search method cannot distinguish between two
// concepts that have the same preferred name but different ids.
function bpFormSelect(li) {
  var input = this.extraParams.input;
  switch (this.extraParams.target_property) {
    case "uri":
      jQuery(input).val(li.extra[3])
      break;
    case "shortid":
      jQuery(input).val(li.extra[0])
      break;
    case "name":
      jQuery(input).val(li.extra[4])
      break;
  }

  jQuery("#" + jQuery(input).attr('name') + "_bioportal_concept_id").val(li.extra[0]);
  jQuery("#" + jQuery(input).attr('name') + "_bioportal_ontology_id").val(li.extra[2]);
  jQuery("#" + jQuery(input).attr('name') + "_bioportal_full_id").val(li.extra[3]);
  jQuery("#" + jQuery(input).attr('name') + "_bioportal_preferred_name").val(li.extra[4]);
}

// Poll for potential definitions returned with results
function getWidgetAjaxContent() {
  // Look for anchors with a get_via_ajax class and replace the parent with the resulting ajax call
  jQuery(".get_definition_via_ajax").each(function(){
    var def_link = jQuery(this);
    if (typeof def_link.attr("getting_content") === 'undefined') {
      def_link.attr("getting_content", true);
      jQuery.getJSON(def_link.attr("href"), function(data){
        var definition = (typeof data.definition === 'undefined') ? "" : data.definition.join(" ");
        def_link.parent().html(truncateText(decodeURIComponent(definition.replace(/\+/g, " "))));
      });
    }
  });
  setTimeout(getWidgetAjaxContent, 100);
}

function truncateText(text, max_length) {
  if (typeof max_length === 'undefined' || max_length == "") {
    max_length = 70;
  }

  var more = '...';

  var content_length = jQuery.trim(text).length;
  if (content_length <= max_length)
    return text;  // bail early if not overlong

  var actual_max_length = max_length - more.length;
  var truncated_node = jQuery("<div>");
  var full_node = jQuery("<div>").html(text).hide();

  text = text.replace(/^ /, '');  // node had trailing whitespace.

  var text_short = text.slice(0, max_length);

  // Ensure HTML entities are encoded
  // http://debuggable.com/posts/encode-html-entities-with-jquery:480f4dd6-13cc-4ce9-8071-4710cbdd56cb
  text_short = jQuery('<div/>').text(text_short).html();

  var other_text = text.slice(max_length, text.length);

  text_short += "<span class='expand_icon'><b>"+more+"</b></span>";
  text_short += "<span class='long_text'>" + other_text + "</span>";
  return text_short;
}

// Start after configuration and callbacks are defined, even when DOM ready has already fired.
(function (server, initialize) {
  if (!window.BioPortalWidgetLoader) {
    window.BioPortalWidgetLoader = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = server.replace(/\/$/, '') + '/javascripts/widgets/dependencies.js';
      script.onload = function () { resolve(window.BioPortalWidgetDependencies); };
      script.onerror = function () {
        window.BioPortalWidgetLoader = null;
        script.remove();
        reject(new Error('Unable to load BioPortal widget dependencies'));
      };
      document.head.appendChild(script);
    });
  }
  window.BioPortalWidgetLoader
    .then(function (dependencies) { return dependencies.load(server); })
    .then(function () { initialize(); })
    .catch(function (error) { console.error(error); });
})(BP_SEARCH_SERVER, bpFormCompleteOnLoad);
