require 'cgi'

module NotesHelper
  include ERB::Util

  NOTES_TAGS = %w(a br b em strong i)

  def recurse_replies(replies)
    return "" if replies.nil?
    html = ""
    replies.each do |reply|
      reply_html = <<-html
        <div class="reply">
          <div class="reply_author">
            <b>#{get_username(reply.creator)}</b> #{time_ago_in_words(DateTime.parse(@note.created))} ago
          </div>
          <div class="reply_body">
            #{sanitize reply.body, tags: NOTES_TAGS}<br/>
          </div>
          <div class="reply_meta">
            <a href="#reply" class="reply_reply" data-parent-id="#{reply.id}" data-parent-type="reply">reply</a>
          </div>
          <div class="discussion">
            <div class="discussion_container">
              #{recurse_replies(reply.respond_to?(:children) ? reply.children : nil)}
            </div>
          </div>
        </div>
      html
      html << reply_html
    end
    html
  end

  def proposal_html(note)
    return "" unless note.respond_to?(:proposal) && note.proposal
    case note.proposal.type
    when "ProposalNewClass"
      html = <<-html
        <table class="proposal">
          <tr>
            <th>Reason for Change</th>
            <td>#{h note.proposal.reasonForChange}</td>
          <tr>
            <th>Contact Info</th>
            <td>#{h note.proposal.contactInfo}</td>
          </tr>
          <tr>
            <th>Preferred Name</th>
            <td>#{h note.proposal.label}</td>
          <tr>
            <th>Provisional id</th>
            <td>#{h note.proposal.classId}</td>
          <tr>
            <th>Parent</th>
            <td>#{h note.proposal.parent}</td>
          </tr>
          <tr>
            <th>Synonyms</th>
            <td>#{h note.proposal.synonym.join(", ")}</td>
          </tr>
          <tr>
            <th>Definition</th>
            <td>#{h note.proposal.definition.join(", ")}</td>
          </tr>
        </table>
      html
    when "ProposalChangeHierarchy"
      html = <<-html
        <table class="proposal">
          <tr>
            <th>Relationship Type</th>
            <td>#{h note.proposal.newRelationshipType.join(", ")}</td>
          </tr>
          <tr>
            <th>New Relationship Target</th>
            <td colspan="3">#{h note.proposal.newTarget}</td>
          </tr>
          <tr>
            <th>Old Relationship Target</th>
            <td colspan="3">#{h note.proposal.oldTarget}</td>
          </tr>
          <tr>
            <th>Reason for Change</th>
            <td>#{h note.proposal.reasonForChange}</td>
          <tr>
            <th>Contact Info</th>
            <td>#{h note.proposal.contactInfo}</td>
          </tr>
        </table>
      html
    when "ProposalChangeProperty"
      html = <<-html
        <table class="proposal">
          <tr>
            <th>Property id</th>
            <td>#{h note.proposal.propertyId}</td>
          </tr>
          <tr>
            <th>New Property Value</th>
            <td colspan="3">#{h note.proposal.newValue}</td>
          </tr>
          <tr>
            <th>Old Property Value</th>
            <td colspan="3">#{h note.proposal.oldValue}</td>
          </tr>
          <tr>
            <th>Reason for Change</th>
            <td>#{h note.proposal.reasonForChange}</td>
          <tr>
            <th>Contact Info</th>
            <td>#{h note.proposal.contactInfo}</td>
          </tr>
        </table>
      html
    end

    html
  end

  def get_note_type_text(note_type)
    case note_type
    when "Comment"
      return "Comment"
    when "ProposalNewClass"
      return "New Class Proposal"
    when "ProposalChangeHierarchy"
      return "New Relationship Proposal"
    when "ProposalChangeProperty"
      return "Change Property Value Proposal"
    end
  end

  def subscribe_button(ontology_id)
    user = session[:user]

    if user.nil?
      return link_to('Subscribe to notes emails', login_index_path, class: 'btn btn-outline-primary btn-sm')
    end

    # Init subscribe button parameters.
    sub_text = "Subscribe"
    params = "data-bp_ontology_id='#{ontology_id}' data-bp_is_subbed='false' data-bp_user_id='#{user.id}'"
    begin
      # Try to create an intelligent subscribe button.
      if ontology_id.start_with? 'http'
        ont = LinkedData::Client::Models::Ontology.find(ontology_id)
      else
        ont = LinkedData::Client::Models::Ontology.find_by_acronym(ontology_id).first
      end
      subscribed = subscribed_to_ontology?(ont.acronym, user)  # application_helper
      sub_text = subscribed ? "Unsubscribe from" : "Subscribe to"
      params = "data-bp_ontology_id='#{ont.acronym}' data-bp_is_subbed='#{subscribed}' data-bp_user_id='#{user.id}'"
    rescue
      # pass, fallback init done above begin block to scope parameters beyond the begin/rescue block
    end
    spinner = '<span class="notes_subscribe_spinner" style="display: none;">' + image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + '</span>'
    error = "<span style='color: red;' class='notes_sub_error'></span>"
    return "<a href='javascript:void(0);' class='subscribe_to_notes btn btn-outline-primary btn-sm' #{params}>#{sub_text} notes emails</a> #{spinner} #{error}".html_safe
  end

  def delete_button
    user = session[:user]
    # TODO_REV: Enable anonymous user
    # user ||= anonymous_user

    params = "data-bp_user_id='#{user.id}'"
    spinner = '<span class="delete_notes_spinner" style="display: none;">' + image_tag("spinners/spinner_000000_16px.gif", style: "vertical-align: text-bottom;") + '</span>'
    error = "<span style='color: red;' class='delete_notes_error'></span>"
    return "<a href='#' onclick='deleteNotes(this);return false;' style='display: inline-block !important;' class='notes_delete link_button' #{params}>Delete selected notes</a> #{spinner} #{error}"
  end

end
