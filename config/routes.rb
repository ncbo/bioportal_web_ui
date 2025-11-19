# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'home#index'

  resources :notes, constraints: { id: /.+/ }

  resources :projects, constraints: { id: /[^\/]+/ }

  resources :users, path: :accounts, constraints: { id: /[\d\w\.\-\%\+\@ ]+/ }

  resources :mappings do
    member do
      get 'count'
    end
  end

  resources :concepts

  scope :ontologies do
    get ':ontology/concepts' => 'concepts#index'
    get ':ontology/concepts/show', to: 'concepts#show'

    get ':ontology/instances', to: 'instances#index'
    get ':ontology/instances/show', to: 'instances#show'

    get ':ontology/properties', to: 'properties#index'
    get ':ontology/properties/show', to: 'properties#show'

    get ':ontology/schemes', to: 'schemes#index'
    get ':ontology/schemes/show', to: 'schemes#show'

    get ':ontology/collections', to: 'collections#index'
    get ':ontology/collections/show', to: 'collections#show'
  end

  get 'ontologies/:ontology_id/concepts', to: 'concepts#show_concept'

  # Ontologies
  resources :ontologies, except: [:destroy] do
    resources :submissions, constraints: { id: /\d+/ } do
      get :edit_properties, on: :member
    end
  end

  resources :ontologies, param: :acronym do
    member do
      get 'admin', to: 'ontologies#admin', as: :admin
      get :submission_log # /ontologies/:acronym/submission_log
      delete :submissions # DELETE /ontologies/:acronym/submissions
      get 'submissions/bulk_delete/:process_id', to: 'ontologies#bulk_delete_status', as: :bulk_delete_status
      get 'submissions/rows', to: 'ontologies#submission_rows', as: :submission_rows
    end
  end

  resources :login

  resources :admin, only: [:index]

  namespace :admin do
    resources :licenses, only: [:index, :create, :new]
  end

  resources :subscriptions

  resources :recommender

  resources :annotator

  resources :annotatorplus

  resources :virtual_appliance

  # Top-level pages
  match '/feedback', to: 'home#feedback', via: [:get, :post]
  get '/help' => 'home#help'
  get '/site_config' => 'home#site_config'
  get '/validate_ontology_file' => 'home#validate_ontology_file_show'
  match '/validate_ontology_file' => 'home#validate_ontology_file', via: [:get, :post]
  get '/layout_partial/:partial' => 'home#render_layout_partial'
  match '/visits', to: 'visits#index', via: :get

  # Error pages
  match '/404', to: 'errors#not_found', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all

  # Analytics
  get 'analytics/search_result_clicked', to: 'analytics#search_result_clicked'
  post 'analytics', to: 'analytics#track'

  # Cookies
  get 'cookies', to: 'cookies#index'
  post 'cookies/consent', to: 'cookies#consent', as: 'cookie_consent'

  # Robots.txt
  get '/robots.txt' => 'robots#index'

  get '/ontologies/success/:id' => 'ontologies#submit_success'
  match '/ontologies/:acronym' => 'ontologies#update', via: [:get, :post]
  match '/ontologies/:acronym/submissions/:id' => 'submissions#update', via: [:get, :post], constraints: { id: /\d+/ }

  get '/ontologies/:ontology_id/submissions/new' => 'submissions#new', :ontology_id => /.+/
  match '/ontologies/:ontology_id/submissions' => 'submissions#create', :ontology_id => /.+/, via: [:get, :post]
  get '/ontologies/:acronym/classes/:purl_conceptid', to: 'ontologies#show', constraints: { purl_conceptid: /[^\/]+/ }
  get '/ontologies/:acronym/:purl_conceptid', to: 'ontologies#show', constraints: { purl_conceptid: /[^\/]+/ }

  # Ontology change requests
  get 'change_requests/create_synonym'
  get 'change_requests/edit_definition'
  get 'change_requests/node_obsoletion'
  get 'change_requests/node_rename'
  get 'change_requests/remove_synonym'
  match 'change_requests', to: 'change_requests#create', via: :post

  # Notes
  get 'ontologies/:ontology/notes/:noteid', to: 'notes#virtual_show', as: :note_virtual, noteid: /.+/

  # Ajax
  get '/ajax/' => 'ajax_proxy#get', :as => :ajax
  get '/ajax_concepts/:ontology/' => 'concepts#show', :constraints => { id: /[^\/?]+/ }
  get '/ajax/class_details' => 'concepts#details'
  get '/ajax/mappings/get_concept_table' => 'mappings#get_concept_table'
  get '/ajax/json_ontology' => 'ajax_proxy#json_ontology'
  get '/ajax/json_class' => 'ajax_proxy#json_class'
  get '/ajax/loading_spinner' => 'ajax_proxy#loading_spinner'
  get '/ajax/notes/delete' => 'notes#destroy'
  get '/ajax/classes/label' => 'concepts#show_label'
  get '/ajax/classes/definition' => 'concepts#show_definition'
  get '/ajax/classes/treeview' => 'concepts#show_tree'
  get '/ajax/properties/tree' => 'concepts#property_tree'
  get '/ajax/biomixer' => 'concepts#biomixer'

  get 'ajax/schemes/label', to: 'schemes#show_label'
  get '/ajax/classes/list' => 'collections#show_members'
  get '/ajax/classes/date_sorted_list' => 'concepts#show_date_sorted_list'
  get 'ajax/collections/label', to: 'collections#show_label'

  # User
  get '/logout' => 'login#destroy', :as => :logout
  get '/lost_pass' => 'login#lost_password'
  get '/reset_password' => 'login#reset_password'
  post '/accounts/:id/custom_ontologies' => 'users#custom_ontologies', :as => :custom_ontologies
  get '/login_as/:login_as' => 'login#login_as', constraints: { login_as:  /[\d\w\.\-\%\+ ]+/ }
  post '/login/send_pass', to: 'login#send_pass'
  get 'password', to: 'passwords#edit', as: :edit_password
  patch 'password', to: 'passwords#update'

  # Search
  get 'search', to: 'search#index'
  get 'search/json_search(/:id)', to: 'search#json_search'

  # Admin
  get '/admin/users', to: 'admin#users'
  post '/admin/clearcache', to: 'admin#clearcache'
  post '/admin/resetcache', to: 'admin#resetcache'
  post '/admin/clear_goo_cache', to: 'admin#clear_goo_cache'
  post '/admin/clear_http_cache', to: 'admin#clear_http_cache'
  get '/admin/ontologies_report', to: 'admin#ontologies_report'
  post '/admin/refresh_ontologies_report', to: 'admin#refresh_ontologies_report'
  delete '/admin/ontologies', to: 'admin#delete_ontologies'
  put '/admin/ontologies', to: 'admin#process_ontologies'
  delete '/admin/ontologies/:acronym/submissions/:id', to: 'admin#delete_submission'
  get '/admin/ontologies/:acronym/submissions', to: 'admin#submissions'
  get '/admin/ontologies/:acronym/log', to: 'admin#parse_log'
  get '/admin/update_info', to: 'admin#update_info'
  get '/admin/update_check_enabled', to: 'admin#update_check_enabled'

end
