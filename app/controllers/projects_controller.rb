# frozen_string_literal: true

class ProjectsController < ApplicationController
  layout :determine_layout

  def index
    @projects = LinkedData::Client::Models::Project.all
    @projects.reject! { |p| p.name.nil? }
    @projects.sort! { |a, b| a.name.downcase <=> b.name.downcase }
    @ontologies = LinkedData::Client::Models::Ontology.all(include_views: true)
    @ontologies_hash = Hash[@ontologies.map { |ont| [ont.id, ont] }]
    if request.xhr?
      render action: 'index', layout: false
    else
      render action: 'index'
    end
  end

  def show
    @project = LinkedData::Client::Models::Project.get(params[:id])
    not_found if @project.nil? || (@project.errors && @project.status == 404)
    @ontologies_used = []
    onts_used = @project.ontologyUsed
    onts_used.each do |ont_used|
      ont = LinkedData::Client::Models::Ontology.get(ont_used, include: 'name,acronym')
      @ontologies_used << Hash['name', ont.name, 'acronym', ont.acronym] unless ont.nil?
    end
    @ontologies_used.sort_by! { |o| o['name'].downcase }
  end

  def new
    if session[:user].nil?
      redirect_to controller: 'login', action: 'index'
    else
      @project = LinkedData::Client::Models::Project.new
      @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
      @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    end
  end

  def edit
    @project = LinkedData::Client::Models::Project.get(params[:id])
    @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
    @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    @usedOntologies = @project.ontologyUsed || []
    @ontologies = LinkedData::Client::Models::Ontology.all
  end

  def create
    @project = LinkedData::Client::Models::Project.new(values: project_params)
    @project_saved = @project.save

    # Project successfully created.
    if response_success?(@project_saved)
      flash[:notice] = 'Project successfully created'
      redirect_to project_path(@project.acronym)
      return
    end

    # Errors creating project.
    if @project_saved.status == 409
      error = OpenStruct.new existence: "Project with acronym #{params[:project][:acronym]} already exists. Please enter a unique acronym."
      @errors = Hash[:error, OpenStruct.new(acronym: error)]
    else
      @errors = response_errors(@project_saved)
    end

    @project = LinkedData::Client::Models::Project.new(values: project_params)
    @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
    @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
    render action: 'new'
  end

  def update
    @project = LinkedData::Client::Models::Project.get(params[:id])
    @project.update_from_params(project_params)
    error_response = @project.update(cache_refresh_all: false)
    if response_error?(error_response)
      @errors = response_errors(error_response)
      @user_select_list = LinkedData::Client::Models::User.all.map { |u| [u.username, u.id] }
      @user_select_list.sort! { |a, b| a[1].downcase <=> b[1].downcase }
      @usedOntologies = @project.ontologyUsed || []
      @ontologies = LinkedData::Client::Models::Ontology.all
      render :edit
    else
      flash[:notice] = 'Project successfully updated'
      redirect_to project_path(@project.acronym)
    end
  end

  def destroy
    @project = LinkedData::Client::Models::Project.get(params[:id])
    error_response = @project.delete
    if response_error?(error_response)
      @errors = response_errors(error_response)
      flash[:notice] = "Project delete failed: #{@errors}"
      respond_to do |format|
        format.html { redirect_to projects_path }
        format.xml  { head :internal_server_error }
      end
    else
      flash[:notice] = 'Project successfully deleted'
      respond_to do |format|
        format.html { redirect_to projects_path }
        format.xml  { head :ok }
      end
    end
  end

  private

  def project_params
    p = params.require(:project).permit(:name, :acronym, :institution, :contacts, { creator: [] }, :homePage,
                                        :description, { ontologyUsed: [] })
    p[:creator].reject!(&:blank?)
    p[:ontologyUsed].reject!(&:blank?)
    p.to_h
  end
end
