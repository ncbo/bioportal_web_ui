# frozen_string_literal: true

class NotesController < ApplicationController
  layout 'ontology'

  def show
    id = clean_note_id(params[:id])

    @note = LinkedData::Client::Models::Note.get(id, include_threads: true)
    @note_decorator = NoteDecorator.new(@note, view_context)
    @ontology = (@note.explore.relatedOntology || []).first

    if request.xhr?
      render partial: 'thread'
      return
    end

    respond_to do |format|
      format.html { render template: 'notes/show' }
    end
  end

  def virtual_show
    note_id = params[:noteid]
    concept_id = params[:conceptid]
    ontology_acronym = params[:ontology]

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ontology_acronym).first

    if note_id
      id = clean_note_id(note_id)
      @note = LinkedData::Client::Models::Note.get(id, include_threads: true)
      @note_decorator = NoteDecorator.new(@note, view_context)
    elsif concept_id
      @notes = @ontology.explore.single_class(concept_id).explore.notes
      @note_link = "/notes/virtual/#{@ontology.ontologyId}/?noteid="
      render partial: 'list', layout: 'ontology'
      return
    else
      @notes = @ontology.explore.notes
      @note_link = "/notes/virtual/#{@ontology.ontologyId}/?noteid="
      render partial: 'list', layout: 'ontology'
      return
    end

    if request.xhr?
      render partial: 'thread'
      return
    end

    respond_to do |format|
      format.html { render :show }
    end
  end

  def create
    if params[:type].eql?('reply')
      note = LinkedData::Client::Models::Reply.new(values: note_params)
    elsif params[:type].eql?('ontology')
      params[:relatedOntology] = [params.delete(:parent)]
      note = LinkedData::Client::Models::Note.new(values: note_params)
    elsif params[:type].eql?('class')
      params[:relatedClass] = [params.delete(:parent)]
      params[:relatedOntology] = params[:relatedClass].map { |c| c['ontology'] }
      note = LinkedData::Client::Models::Note.new(values: note_params)
    else
      note = LinkedData::Client::Models::Note.new(values: note_params)
    end

    new_note = note.save

    if new_note.errors
      render json: new_note.errors, status: 500
      return
    end

    unless new_note.nil?
      render json: new_note.to_hash.to_json
    end
  end

  def destroy
    note_ids = params[:noteids].kind_of?(String) ? params[:noteids].split(',') : params[:noteids]

    ontology = DataAccess.getOntology(params[:ontologyid])

    errors = []
    successes = []
    note_ids.each do |note_id|
      begin
        result = DataAccess.deleteNote(note_id, ontology.ontologyId, params[:concept_id])
        raise Exception if !result.nil? && result['errorCode']
      rescue Exception => e
        errors << note_id
        next
      end
      successes << note_id
    end

    render json: { success: successes, error: errors }
  end

  def archive
    ontology = DataAccess.getLatestOntology(params[:ontology_virtual_id])

    unless ontology.admin?(session[:user])
      render json: nil.to_json, status: 500
      return
    end

    @archive = DataAccess.archiveNote(params)

    unless @archive.nil?
      render json: @archive.to_json
    end
  end

  private

  def note_params
    p = params.permit(:parent, :type, :subject, :body, :creator, { relatedClass:[:class, :ontology] }, { relatedOntology:[] },
                      proposal: [:type, :reasonForChange, :classId, :label, { synonym:[] }, { definition:[] },
                                 :parent, :newTarget, :oldTarget, { newRelationshipType:[] }, :propertyId,
                                 :newValue, :oldValue])
    p.to_h
  end

  # Fix noteid parameters with bad prefixes (some application servers, e.g., Apache, NGINX, mangle encoded slashes).
  def clean_note_id(id)
    id = id.match(/\Ahttp:\/\w/) ? id.sub('http:/', 'http://') : id
    CGI.unescape(id)
  end
end
