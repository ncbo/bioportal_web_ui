import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="notes" on the .notes_list_container in both the
// ontology Notes tab (notes/_ontology_list) and the concept Notes sub-tab
// (notes/_list). Owns the note/comment/proposal/reply interactions that used to
// live in app/assets/javascripts/bp_notes.js plus the inline :javascript blocks
// in those partials.
//
// Why document-level delegation with explicit teardown:
// The note-view and reply forms are rendered inside a facebox modal that facebox
// appends to <body> — i.e. outside this.element. So the click handlers have to be
// delegated from document. The original code bound them with jQuery's deprecated
// .live() (a document-level delegate) and re-ran the binders on every partial
// render without ever removing them; the handlers stacked, so a single "save"
// click fired N POST /notes requests and created N duplicate notes (issue #401).
// Here each controller instance adds exactly one set of listeners in connect()
// and removes them in disconnect(), so only one is ever live at a time.
//
// jQuery is still used for the DOM-building helpers and facebox (a jQuery plugin),
// so it stays loaded regardless. The network calls have been moved to fetch.
// We read window.jQuery (not an npm import) because facebox is attached to the
// global jQuery from the Sprockets vendor bundle.
export default class extends Controller {
  static PROPOSAL_TYPES = {
    ProposalNewClass: 'New Class Proposal',
    ProposalChangeHierarchy: 'New Relationship Proposal',
    ProposalChangeProperty: 'Change Property Value Proposal',
  };

  connect() {
    this.$ = window.jQuery;

    this.onClick = this.onClick.bind(this);
    this.onChange = this.onChange.bind(this);
    this.faceboxSizing = this.faceboxSizing.bind(this);

    document.addEventListener('click', this.onClick);
    document.addEventListener('change', this.onChange);

    this.setupFacebox();
    this.$(document).on('afterReveal.facebox', this.faceboxSizing);
  }

  disconnect() {
    document.removeEventListener('click', this.onClick);
    document.removeEventListener('change', this.onChange);
    this.$(document).off('afterReveal.facebox', this.faceboxSizing);
  }

  // --- Event delegation -----------------------------------------------------

  onClick(event) {
    const target = event.target;

    const addComment = target.closest('a.add_comment');
    if (addComment && this.element.contains(addComment)) {
      this.addCommentBox(addComment.dataset.parentId, addComment.dataset.parentType, addComment);
      return;
    }

    const addProposal = target.closest('a.add_proposal');
    if (addProposal && this.element.contains(addProposal)) {
      this.addProposalBox(addProposal.dataset.parentId, addProposal.dataset.parentType, addProposal);
      return;
    }

    if (target.closest('.reply .save, .create_note_form .save')) {
      this.save(target.closest('.save'));
      return;
    }

    if (target.closest('.reply .cancel, .create_note_form .cancel')) {
      this.removeReplyBox(target.closest('.cancel'));
      return;
    }

    const replyLink = target.closest('a.reply_reply');
    if (replyLink) {
      this.addReplyBox(replyLink);
      replyLink.style.display = 'none';
      return;
    }

    const subscribe = target.closest('a.subscribe_to_notes');
    if (subscribe && this.element.contains(subscribe)) {
      this.subscribe(subscribe);
    }
  }

  onChange(event) {
    const target = event.target;

    if (target.closest('.create_note_form .proposal_type')) {
      const select = this.$(target);
      this.proposalFields(select.val(), select.parent().children('.proposal_container'));
      return;
    }

    if (target.id === 'hide_archived_ont') {
      this.hideOrUnhideArchivedOntNotes();
    }
  }

  // --- Facebox (view note / replies modal) ----------------------------------

  setupFacebox() {
    this.$('a.notes_list_link', this.element).attr('rel', 'facebox[.facebox_note]');
    this.$('a.notes_list_link', this.element).each(function () {
      if (!window.jQuery(this).data().faceboxInit) {
        window.jQuery(this).facebox();
        window.jQuery(this).data().faceboxInit = true;
      }
    });
  }

  faceboxSizing() {
    const $ = this.$;
    $('div.facebox_note').parents('div#facebox').width('850px');
    $('div.facebox_note').width('820px');
    $('div.facebox_note')
      .parents('div#facebox')
      .css('max-height', $(window).height() - ($('#facebox').offset().top - $(window).scrollTop()) * 2 + 'px');
    $('div.facebox_note').parents('div#facebox').centerElement();
  }

  // --- Comment / proposal forms ---------------------------------------------

  addCommentBox(id, type, button) {
    const $ = this.$;
    const formContainer = $(button).parents('.notes_list_container').children('.create_note_form');
    const commentSubject = $('<input>')
      .attr('type', 'text')
      .attr('placeholder', 'Subject')
      .addClass('comment_subject')
      .add('<br>');
    const commentFields = commentSubject.add(this.commentForm(id, type));
    const commentWrapper = $('<div>').addClass('reply_box').append(commentFields);
    formContainer.html(commentWrapper);
    formContainer.show();
  }

  addProposalBox(id, type, button) {
    const $ = this.$;
    const types = this.constructor.PROPOSAL_TYPES;
    const formContainer = $(button).parents('.notes_list_container').children('.create_note_form');
    const proposalForm = $('<div>').addClass('reply_box');
    const select = $('<select>').addClass('proposal_type');

    for (const proposalType in types) {
      select.append($('<option>').attr('value', proposalType).html(types[proposalType]));
    }
    proposalForm.html('Proposal type: ');
    proposalForm.append(select);
    proposalForm.append('<br/>');

    const proposalContainer = $('<div>').addClass('proposal_container');
    this.proposalFields(Object.keys(types).shift(), proposalContainer);

    proposalForm.append(proposalContainer);
    proposalForm.append($('<div>').addClass('proposal_buttons').append(this.commentButtons(id, type)));
    formContainer.html(proposalForm);
    formContainer.show();
  }

  commentForm(id, type) {
    return this.commentTextArea().add(this.commentButtons(id, type));
  }

  commentTextArea() {
    return this.$('<textarea>')
      .addClass('reply_body')
      .attr('rows', '1')
      .attr('cols', '1')
      .attr('name', 'text')
      .attr('tabindex', '0')
      .attr('placeholder', 'Comment')
      .css({ width: '500px', height: '100px' })
      .add('<br>');
  }

  commentButtons(id, type) {
    const $ = this.$;
    const buttonSubmit = $('<button>')
      .attr('type', 'submit')
      .attr('onclick', '')
      .data('parent_id', id)
      .data('parent_type', type)
      .addClass('save')
      .html('save');
    const buttonCancel = $('<button>').attr('type', 'button').attr('onclick', '').addClass('cancel').html('cancel');
    const spanStatus = $('<span>').addClass('reply_status').css({ color: 'red', paddingLeft: '5px' });
    return buttonSubmit.add(buttonCancel).add(spanStatus);
  }

  // --- Proposal fields ------------------------------------------------------

  appendField(id, text, div) {
    div.append(this.$('<input>').attr('type', 'text').attr('id', id).attr('placeholder', text));
    div.append('<br/>');
  }

  proposalFields(type, container) {
    container.html('');
    this.appendField('reasonForChange', 'Reason for change', container);
    if (type === 'ProposalChangeHierarchy') {
      this.appendField('newTarget', 'New target', container);
      this.appendField('oldTarget', 'Old target', container);
      this.appendField('newRelationshipType', 'Relationship type', container);
    } else if (type === 'ProposalChangeProperty') {
      this.appendField('propertyId', 'Property id', container);
      this.appendField('newValue', 'New value', container);
      this.appendField('oldValue', 'Old Value', container);
    } else if (type === 'ProposalNewClass') {
      this.appendField('classId', 'Class id', container);
      this.appendField('label', 'Label', container);
      this.appendField('synonym', 'Synonym', container);
      this.appendField('definition', 'Definition', container);
      this.appendField('parent', 'Parent', container);
    }
  }

  proposalMap(button) {
    const $ = this.$;
    const formContainer = $(button).parents('.notes_list_container').children('.create_note_form');
    const lists = ['synonym', 'definition', 'newRelationshipType'];
    const map = {};
    map['type'] = formContainer.find('.proposal_type').val();
    formContainer.find('.proposal_container input').each(function () {
      const input = window.jQuery(this);
      const id = input.attr('id');
      map[id] = $.inArray(id, lists) >= 0 ? input.val().split(',') : input.val();
    });
    return map;
  }

  subjectForNote(button) {
    const $ = this.$;
    let subject = $(button).closest('.reply_box').children('.comment_subject').val();
    const reasonForChange = $('input#reasonForChange');
    if (typeof subject === 'undefined' || (subject.length === 0 && reasonForChange.length > 0)) {
      subject = this.constructor.PROPOSAL_TYPES[$('.proposal_type').val()] + ': ' + reasonForChange.val();
    }
    return subject;
  }

  // --- Save (create note / reply) -------------------------------------------

  save(button) {
    const $ = this.$;
    const user = this.getUser();
    let id = $(button).data('parent_id');
    const type = $(button).data('parent_type');
    const body = $(button).closest('.reply_box').children('.reply_body').val();
    const subject = this.subjectForNote(button);
    const ontologyId = $(document).data().bp.ont_viewer.ontology_id;
    $(button).parent().children('.reply_status').html('');

    if (type === 'class') {
      id = { class: id, ontology: ontologyId };
    }

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
    fetch('/notes', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify({
        parent: id,
        type: type,
        subject: subject,
        body: body,
        proposal: this.proposalMap(button),
        creator: user['id'],
      }),
    })
      .then(async (r) => {
        const note = await r.json().catch(() => ({}));
        if (!r.ok) {
          this.displayError(button);
          return;
        }
        this.addNoteOrReply(button, note);
        this.removeReplyBox(button);
      })
      .catch(() => this.displayError(button));
  }

  displayError(button) {
    this.$(button).parent().children('.reply_status').html('Error, please try again');
  }

  // --- Render created note / reply ------------------------------------------

  addNoteOrReply(button, note) {
    if (note['type'] === 'http://data.bioontology.org/metadata/Note') {
      this.addNote(button, note);
    } else if (note['type'] === 'http://data.bioontology.org/metadata/Reply') {
      this.addReply(button, note);
    }
  }

  addNote(button, note) {
    const $ = this.$;
    const user = this.getUser();
    const id = note['id'].split('/').pop();
    const created = note['created'].split('T')[0];
    const noteType = this.getNoteType(note);

    // Add note to concept table (if we're on a concept page)
    if ($(button).closest('#notes_content').length > 0) {
      const jRow = $('<tr>');
      jRow.append($('<td>').html(this.generateNoteLink('concept_' + id, note)));
      jRow.append($('<td>').html(user['username']));
      jRow.append($('<td>').html(noteType));
      jRow.append($('<td>').html(created));
      $('table.concept_notes_list').prepend(jRow);
      $('#note_count').html(parseInt($('#note_count').html()) + 1);
      $('a#concept_' + id).facebox();
    }

    // Add note to main ontology notes table (DataTable owned by
    // ontology_notes_table_controller, exposed as window.ontNotesTable).
    if (typeof window.ontNotesTable !== 'undefined' && window.ontNotesTable) {
      const noteLink = this.generateNoteLink(id, note);
      const noteLinkHTML = $('<div>').append(noteLink).html();
      const noteRow = [
        '', // Delete
        noteLinkHTML,
        note['subject'],
        'false', // Archived
        user['username'],
        noteType,
        '', // Class
        created,
      ];
      window.ontNotesTable.row.add(noteRow).draw();
    }
    $('a#' + id).facebox();
  }

  addReply(button, note) {
    const $ = this.$;
    const user = this.getUser();
    const reply = $('<div>').addClass('reply');
    const replyAuthor = $('<div>')
      .addClass('reply_author')
      .html('<b>' + user['username'] + '</b> seconds ago');
    const replyBody = $('<div>').addClass('reply_body').html(note.body);
    const replyMeta = $('<div>').addClass('reply_meta');
    replyMeta.append(
      $('<a>').addClass('reply_reply').attr('data-parent-id', note['id']).attr('href', '#reply').html('reply'),
    );
    reply.append(replyAuthor).append(replyBody).append(replyMeta);
    $(button).closest('div.reply').children('.discussion').children('.discussion_container').prepend(reply);
  }

  addReplyBox(button) {
    const $ = this.$;
    const id = $(button).attr('data-parent-id');
    const type = $(button).attr('data-parent-type');
    const formHTML = this.commentForm(id, type);
    $(button).closest('div.reply').children('div.reply_meta').append($('<div>').addClass('reply_box').html(formHTML));
  }

  removeReplyBox(button) {
    const $ = this.$;
    $(button).closest('div.reply').children('.reply_meta').children('a.reply_reply').show();
    $(button).closest('div.reply').children('.reply_meta').children('.reply_box').remove();
    $(button).closest('.create_note_form').html('');
  }

  generateNoteLink(id, note) {
    const ontologyId = this.$(document).data().bp.ont_viewer.ontology_id;
    return this.$('<a>')
      .addClass('ont_notes_list_link')
      .addClass('notes_list_link')
      .attr('href', '/ontologies/' + ontologyId + '/notes/' + encodeURIComponent(note['id']))
      .attr('id', id)
      .html(note['subject']);
  }

  getNoteType(note) {
    if (typeof note['proposal'] !== 'undefined') {
      return this.constructor.PROPOSAL_TYPES[note['proposal'][0]];
    }
    return 'Comment';
  }

  // --- Subscribe to notes emails --------------------------------------------

  subscribe(button) {
    const $ = this.$;
    const ontologyId = $(button).attr('data-bp_ontology_id');
    const isSubbed = $(button).attr('data-bp_is_subbed');
    const userId = $(button).attr('data-bp_user_id');
    const encodedUserId = encodeURIComponent(userId);

    $('.notes_sub_error').html('');
    $('.notes_subscribe_spinner').show();

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
    fetch(`/subscriptions?user_id=${encodedUserId}&ontology_id=${ontologyId}&subbed=${isSubbed}`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest',
      },
    })
      .then((r) => {
        if (!r.ok) {
          throw new Error(`Subscribe failed: ${r.status}`);
        }
        $('.notes_subscribe_spinner').hide();

        const subbedVal = isSubbed === 'true' ? 'false' : 'true';
        $('a.subscribe_to_notes').attr('data-bp_is_subbed', subbedVal);

        // There are two subscribe/unsubscribe links (top-level Notes tab and the
        // Notes sub-tab on the Classes tab). Update the text of both.
        document.querySelectorAll('a.subscribe_to_notes').forEach((match) => {
          match.textContent = subbedVal === 'true' ? 'Unsubscribe from notes emails' : 'Subscribe to notes emails';
        });
      })
      .catch(() => {
        $('.notes_subscribe_spinner').hide();
        $('.notes_sub_error').html('Problem subscribing to emails, please try again');
      });
  }

  // --- Archived notes filter ------------------------------------------------

  hideOrUnhideArchivedOntNotes() {
    const archivedColumn = 3;
    if (this.$('#hide_archived_ont:checked').val() !== undefined) {
      window.ontNotesTable.column(archivedColumn).search('false').draw();
    } else {
      window.ontNotesTable.column(archivedColumn).search('', true, false).draw();
    }
  }

  // --- Helpers --------------------------------------------------------------

  getUser() {
    return this.$(document).data().bp.user;
  }
}
