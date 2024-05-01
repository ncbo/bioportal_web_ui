/* Ontology viewing */

/* Ontology creation & editing */

function hideAllRestrictions() {
  jQuery(".viewing_restriction_disabled").attr("disabled", true);
  jQuery("div.viewing_restriction_types").addClass("hidden");
}

function showRestrictionPrivate() {
  jQuery("#ontology_acl").removeAttr("disabled");
  jQuery("#viewingRestrictionsPrivate").removeClass("hidden");
}

function showRestrictionLicensed() {
  jQuery("#ontology_licenseInformation").removeAttr("disabled");
  jQuery("#viewingRestrictionsLicensed").removeClass("hidden");
}

jQuery(document).ready(function() {

  // Wire up options for restriction how an ontology is viewed
  jQuery("#ontology_viewingRestriction").change(function(){
    var select = jQuery(this);
    if (select.val() == "private") {
      hideAllRestrictions()
      showRestrictionPrivate();
    } else if (select.val() == "licensed") {
      hideAllRestrictions();
      showRestrictionLicensed();
    } else if (select.val() == "public") {
      hideAllRestrictions();
    }
  });

  // Make sure you can see the account select if the select list has private selected
  if (jQuery("#ontology_viewingRestriction").val() == "private") {
    showRestrictionPrivate();
  } else if (jQuery("#ontology_viewingRestriction").val() == "licensed") {
    showRestrictionLicensed();
  }

  jQuery("#ontology_isView").live("click", function(){
    console.log(jQuery("#ontology_isView").is(":checked"))
    if (jQuery("#ontology_isView").is(":checked")) {
      jQuery("#ontology_viewOf").removeAttr('disabled').trigger("chosen:updated");
    } else {
      jQuery("#ontology_viewOf").attr('disabled', true).trigger("chosen:updated");
    }
  });

  jQuery('#ontology-browse-help').on('click', bpPopWindow);

  // Wire up chosen selectors
  jQuery("#ontology_administeredBy").chosen({width: '100%'});
  jQuery("#ontology_acl").chosen({width: '100%'});
  jQuery("#ontology_hasDomain").chosen({width: '100%'});

  // Make acronym upcase as you type
  jQuery("#ontology_acronym").on('input', function(e) {
    var input = $(this);
    var start = input[0].selectionStart;
    $(this).val(function (_, val) {
      return val.toUpperCase();
    });
    input[0].selectionStart = input[0].selectionEnd = start;
  });

  // Check acronym as you type
  var acronyms = jQuery("#ontology_acronym").data("acronyms");
  jQuery("#ontology_acronym").on('input', function(e) {
    var $this = $(this);
    var errors = [];
    var errorHTML = "";

    if ($this.val().match("^[^a-z^A-Z]{1}")) {
      errors.push("Acronym must start with a letter");
    }

    if ($this.val().match("[^-_0-9a-zA-Z]")) {
      errors.push("Acronym must only contain the folowing characters: -, _, letters, and numbers");
    }

    if ($this.val().match(".{17,}")) {
      errors.push("Acronym must be sixteen characters or less");
    }

    if (acronyms.indexOf($this.val()) > -1) {
      errors.push("Acronym already in use");
    }

    if (errors.length > 0) {
      errorHTML = "<li>" + errors.join("</li><li>") + "</li>";
    }

    jQuery("#acronym_errors").html(errorHTML);
  });

  jQuery("#ontologyForm").validate({
    errorClass: "ontologyFormError",
    errorElement: "div",
    rules: {
      "ontology[name]": "required",
      "ontology[acronym]": "required",
    },
    messages: {
      "ontology[name]": "Please enter a name",
      "ontology[acronym]": "Please enter an acronym",
    },
  });
});

