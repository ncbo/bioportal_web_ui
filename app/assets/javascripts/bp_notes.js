var ontNotesTable;
var ont_columns = { archived: 3, date: 7, subjectSort: 2 };


NOTES_PROPOSAL_TYPES = {
  "ProposalNewClass": "New Class Proposal",
  "ProposalChangeHierarchy": "New Relationship Proposal",
  "ProposalChangeProperty": "Change Property Value Proposal"
}

function getUser() {
  return jQuery(document).data().bp.user;
}

function setupNotesFacebox() {
  jQuery("a.notes_list_link").attr("rel", "facebox[.facebox_note]");
  jQuery("a.notes_list_link").each(function() {
    if (!jQuery(this).data().faceboxInit) {
      jQuery(this).facebox();
      jQuery(this).data().faceboxInit = true;
    }
  })
}

function setupNotesFaceboxSizing() {
  jQuery(document).bind('afterReveal.facebox', function() {
    jQuery("div.facebox_note").parents("div#facebox").width('850px');
    jQuery("div.facebox_note").width('820px');
    jQuery("div.facebox_note").parents("div#facebox").css("max-height", jQuery(window).height() - (jQuery("#facebox").offset().top - jQuery(window).scrollTop()) * 2 + "px");
    jQuery("div.facebox_note").parents("div#facebox").centerElement();
  });
}

function bindAddCommentClick() {
  jQuery("a.add_comment").live('click', function(){
    var id = jQuery(this).attr("data-parent-id");
    var type = jQuery(this).attr("data-parent-type");
    addCommentBox(id, type, this);
  });
}

function bindAddProposalClick() {
  jQuery("a.add_proposal").live('click', function(){
    var id = jQuery(this).attr("data-parent-id");
    var type = jQuery(this).attr("data-parent-type");
    addProposalBox(id, type, this);
  });
}

function bindReplyClick() {
  jQuery("a.reply_reply").live('click', function(){
    addReplyBox(this);
    jQuery(this).hide();
  });
}

function bindReplyCancelClick() {
  jQuery(".reply .cancel, .create_note_form .cancel").live('click', function(){
    removeReplyBox(this);
  });
}

function bindProposalChange() {
  jQuery(".create_note_form .proposal_type").live('change', function(){
    var selector = jQuery(this);
    proposalFields(selector.val(), selector.parent().children(".proposal_container"));
  });
}

function bindReplySaveClick() {
  jQuery(".reply .save, .create_note_form .save").live('click', function(){
    var user = getUser();
    var id = jQuery(this).data("parent_id");
    var type = jQuery(this).data("parent_type");
    var button = this;
    var body = jQuery(this).closest(".reply_box").children(".reply_body").val();
    var subject = subjectForNote(button);
    var ontology_id = jQuery(document).data().bp.ont_viewer.ontology_id;
    jQuery(button).parent().children(".reply_status").html("");
    if (type === "class") {
      id = {class: id, ontology: ontology_id};
    }
    jQuery.ajax({
      type: "POST",
      url: "/notes",
      data: {parent: id, type: type, subject: subject, body: body, proposal: proposalMap(button), creator: user["id"]},
      success: function(data){
        var note = data;
        var status = data[1];
        if (status && status >= 400) {
          displayError(button);
        } else {
          addNoteOrReply(button, note);
          removeReplyBox(button);
        }
      },
      error: function(){displayError(button);}
    });
  });
}


var displayError = function(button) {
  jQuery(button).parent().children(".reply_status").html("Error, please try again");
}

function addCommentBox(id, type, button) {
  var formContainer = jQuery(button).parents(".notes_list_container").children(".create_note_form");
  var commentSubject = jQuery("<input>")
    .attr("type", "text")
    .attr("placeholder", "Subject")
    .addClass("comment_subject")
    .add("<br>");
  var commentFields = commentSubject.add(commentForm(id,type));
  var commentWrapper = jQuery("<div>").addClass("reply_box").append(commentFields);
  formContainer.html(commentWrapper);
  formContainer.show();
}

function addProposalBox(id, type, button) {
  var formContainer = jQuery(button).parents(".notes_list_container").children(".create_note_form");
  var proposalForm = jQuery("<div>").addClass("reply_box");
  var select = jQuery("<select>").addClass("proposal_type");
  var proposalContainer;
  for (var proposalType in NOTES_PROPOSAL_TYPES) {
    select.append(jQuery("<option>").attr("value", proposalType).html(NOTES_PROPOSAL_TYPES[[proposalType]]));
  }
  proposalForm.html("Proposal type: ");
  proposalForm.append(select);
  proposalForm.append("<br/>");

  proposalContainer = jQuery("<div>").addClass("proposal_container");

  // Proposal-specific fields
  proposalFields(Object.keys(NOTES_PROPOSAL_TYPES).shift(), proposalContainer);

  proposalForm.append(proposalContainer);
  proposalForm.append(jQuery("<div>").addClass("proposal_buttons").append(commentButtons(id, type)));
  formContainer.html(proposalForm);
  formContainer.show();
}

function addNoteOrReply(button, note) {
  if (note["type"] === "http://data.bioontology.org/metadata/Note") {
    // Create a new note in the note table
    addNote(button, note);
  } else if (note["type"] === "http://data.bioontology.org/metadata/Reply") {
    // Create a new reply in the thread
    addReply(button, note);
  }
}

function addNote(button, note) {
  var user = getUser();
  var id = note["id"].split("/").pop();
  var noteLink = generateNoteLink(id, note);
  var noteLinkHTML = jQuery("<div>").append(noteLink).html();
  var created = note["created"].split("T")[0];
  // TODO_REV: Add column for note delete checkbox
  var deleteBox = "";
  var noteType = getNoteType(note);
  var noteRow = [deleteBox, noteLinkHTML, note["subject"], "false", user["username"], noteType, "", created];
  // Add note to concept table (if we're on a concept page)
  if (jQuery(button).closest("#notes_content").length > 0) {
    var jRow = jQuery("<tr>");
    jRow.append(jQuery("<td>").html(generateNoteLink("concept_"+id, note)));
    jRow.append(jQuery("<td>").html(user["username"]));
    jRow.append(jQuery("<td>").html(noteType));
    jRow.append(jQuery("<td>").html(created));
    jQuery("table.concept_notes_list").prepend(jRow);
    jQuery("#note_count").html(parseInt(jQuery("#note_count").html()) + 1);
    jQuery("a#concept_"+id).facebox();
  }
  // Add note to main table
  if (typeof ontNotesTable !== "undefined") {
    ontNotesTable.fnAddData(noteRow);
  }
  jQuery("a#"+id).facebox();
}

function addReply(button, note) {
  var user = getUser();
  var reply = jQuery("<div>").addClass("reply");
  var replyAuthor = jQuery("<div>").addClass("reply_author").html("<b>"+user["username"]+"</b> seconds ago");
  var replyBody = jQuery("<div>").addClass("reply_body").html(note.body);
  var replyMeta = jQuery("<div>").addClass("reply_meta");
  replyMeta.append(jQuery("<a>").addClass("reply_reply").attr("data-parent-id", note["id"]).attr("href", "#reply").html("reply"));
  reply.append(replyAuthor).append(replyBody).append(replyMeta);
  jQuery(button).closest("div.reply").children(".discussion").children(".discussion_container").prepend(reply);
}

function addReplyBox(button) {
  var id = jQuery(button).attr("data-parent-id");
  var type = jQuery(button).attr("data-parent-type");
  var formHTML = commentForm(id, type);
  jQuery(button).closest("div.reply").children("div.reply_meta").append(jQuery("<div>").addClass("reply_box").html(formHTML));
}

function removeReplyBox(button) {
  jQuery(button).closest("div.reply").children(".reply_meta").children("a.reply_reply").show();
  jQuery(button).closest("div.reply").children(".reply_meta").children(".reply_box").remove();
  jQuery(button).closest(".create_note_form").html("");
}

function commentForm(id, type) {
  return commentTextArea().add(commentButtons(id, type));
}

function commentTextArea() {
  return jQuery("<textarea>")
    .addClass("reply_body")
    .attr("rows","1")
    .attr("cols","1")
    .attr("name","text")
    .attr("tabindex","0")
    .attr("placeholder","Comment")
    .css({"width": "500px", "height": "100px"})
    .add("<br>");
}

function commentButtons(id, type) {
  var button_submit = jQuery("<button>")
    .attr("type","submit")
    .attr("onclick","")
    .data("parent_id", id)
    .data("parent_type", type)
    .addClass("save")
    .html("save");
  var button_cancel = jQuery("<button>")
    .attr("type","button")
    .attr("onclick","")
    .addClass("cancel")
    .html("cancel");
  var span_status = jQuery("<span>")
    .addClass("reply_status")
    .css({"color": "red", "paddingLeft": "5px"});
  return button_submit.add(button_cancel).add(span_status);
}

function appendField(id, text, div) {
  if (jQuery.browser.msie && parseInt(jQuery.browser.version) < 10) {
    div.append(jQuery("<span>").css("font-weight", "bold").html(text));
    div.append("<br/>");
  }
  div.append(jQuery("<input>").attr("type", "text").attr("id", id).attr("placeholder", text));
  div.append("<br/>");
}

function proposalFields(type, container) {
  container.html("");
  appendField("reasonForChange", "Reason for change", container);
  if (type === "ProposalChangeHierarchy") {
    appendField("newTarget", "New target", container);
    appendField("oldTarget", "Old target", container);
    appendField("newRelationshipType", "Relationship type", container);
  } else if (type === "ProposalChangeProperty") {
    appendField("propertyId", "Property id", container);
    appendField("newValue", "New value", container);
    appendField("oldValue", "Old Value", container);
  } else if (type === "ProposalNewClass") {
    appendField("classId", "Class id", container);
    appendField("label", "Label", container);
    appendField("synonym", "Synonym", container);
    appendField("definition", "Definition", container);
    appendField("parent", "Parent", container);
  }
}

function proposalMap(button) {
  var formContainer = jQuery(button).parents(".notes_list_container").children(".create_note_form");
  var lists = ["synonym", "definition", "newRelationshipType"];
  var map = {};
  map["type"] = formContainer.find(".proposal_type").val();
  console.log(formContainer.find(".proposal_container input"))
  formContainer.find(".proposal_container input").each(function(){
    var input = jQuery(this);
    var id = input.attr("id");
    var val = (jQuery.inArray(id, lists) >= 0) ? input.val().split(",") : input.val();
    map[id] = val;
  });
  return map;
}

function subjectForNote(button) {
  var subject = jQuery(button).closest(".reply_box").children(".comment_subject").val();
  var reasonForChange = jQuery("input#reasonForChange");
  if (typeof subject === "undefined" || (subject.length === 0 && reasonForChange.length > 0)) {
    subject = NOTES_PROPOSAL_TYPES[$(".proposal_type").val()] + ": " + reasonForChange.val();
  }
  return subject;
}

function generateNoteLink(id, note) {
  return jQuery("<a>")
    .addClass("ont_notes_list_link")
    .addClass("notes_list_link")
    .attr("href", "/ontologies/"+jQuery(document).data().bp.ont_viewer.ontology_id+"/notes/"+encodeURIComponent(note["id"]))
    .attr("id", id)
    .html(note["subject"]);
}

function getNoteType(note) {
  if (typeof note["proposal"] !== "undefined") {
    return NOTES_PROPOSAL_TYPES[note["proposal"][0]];
  } else {
    return "Comment";
  }
}

function subscribeToNotes(button) {
  var ontologyId = jQuery(button).attr("data-bp_ontology_id");
  var isSubbed = jQuery(button).attr("data-bp_is_subbed");
  var userId = jQuery(button).attr("data-bp_user_id");
  let encodedUserId = encodeURIComponent(userId);

  jQuery(".notes_sub_error").html("");
  jQuery(".notes_subscribe_spinner").show();

  jQuery.ajax({
    type: "POST",
    url: `/subscriptions?user_id=${encodedUserId}&ontology_id=${ontologyId}&subbed=${isSubbed}`,
    dataType: "json",
    success: function(data) {
      jQuery(".notes_subscribe_spinner").hide();

      // Change subbed value on a element
      var subbedVal = (isSubbed == "true") ? "false" : "true";
      jQuery("a.subscribe_to_notes").attr("data-bp_is_subbed", subbedVal);

      /*
       * Update link text.
       * Note that there are two links that allow users to subscribe/unsubscribe from notes emails. Given any ontology,
       * one link is located on the top-level Notes tab, and the other link is located on the Notes sub-tab on the
       * right-hand side of the Classes tab. Both links are handled by the subscriptions controller, and the text of
       * both should be updated on success.
       */
      const matches = document.querySelectorAll('a.subscribe_to_notes');
      matches.forEach(match => {
        match.textContent = (subbedVal === 'true') ? 'Unsubscribe from notes emails' : 'Subscribe to notes emails';
      });
    },
    error: function(data) {
      jQuery(".notes_subscribe_spinner").hide();
      jQuery(".notes_sub_error").html("Problem subscribing to emails, please try again");
    }
  });
}

function hideOrUnhideArchivedOntNotes() {
  if (jQuery("#hide_archived_ont:checked").val() !== undefined) {
    // Checked
    ontNotesTable.fnFilter('false', ont_columns.archived);
  } else {
    // Unchecked
    ontNotesTable.fnFilter('', ont_columns.archived, true, false);
  }
}

function wireOntTable(ontNotesTableNew) {
  jQuery.data(document.body, "ontology_id", "#{@ontology.acronym}");

  ontNotesTable = ontNotesTableNew;
  ontNotesTable.dataTable({
    "iDisplayLength": 50,
    "sPaginationType": "full_numbers",
    "aaSorting": [[ont_columns.date, 'desc']],
    "aoColumns": [
      { "bVisible": false }, // Delete
      { "iDataSort": ont_columns.subjectSort }, // Subject link
      { "bVisible": false }, // Subject for sort
      { "bVisible": false }, // Archived for filter
      null, // Author
      null, // Type
      null, // Target
      null // Created
    ],
  });
  // Important! Table is somehow getting set to zero width. Reset here.
  jQuery(ontNotesTable).css("width", "100%");
  ontNotesTable.fnFilter('false', ont_columns.archived);
}
