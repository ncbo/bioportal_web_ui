Rails.application.routes.draw do
  match 'cookies', to: 'home#set_cookies', via: [:post, :get]

  root to: 'home#index'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  get'/tools', to: 'home#tools'
  get 'auth/:provider/callback', to: 'login#create_omniauth'
  get 'locale/:language', to: 'language#set_locale_language'
  get 'metadata_export/index'
  get '/config', to: 'home#portal_config'

  get '/notes/new_comment', to: 'notes#new_comment'
  get '/notes/new_proposal', to: 'notes#new_proposal'
  get '/notes/new_reply', to: 'notes#new_reply'
  delete '/notes', to: 'notes#destroy'
  resources :notes, constraints: { id: /.+/ }

  # Agents
  get 'agents/:id', to: 'agents#details',  constraints: { id: /[0-9a-f\-]+/ }
  get 'agents/:id/show', to: 'agents#show',  constraints: { id: /[0-9]+/ }
  get 'agents/show_search', to: 'agents#show_search'
  get 'agents/:id/usages', to: 'agents#agent_usages', constraints: { id: /.+/ }
  post 'agents/:id/usages', to: 'agents#update_agent_usages', constraints: { id: /.+/ }
  resources :agents, constraints: { id: /.+/ }
  post 'agents/:id', to: 'agents#update', constraints: { id: /.+/ }

  resources :projects, constraints: { id: /[^\/]+/ }

  resources :users, path: :accounts, constraints: { id: /[\d\w\.\@\-\%\+ ]+/ }

  get '/users/subscribe/:username', to: 'users#subscribe'
  get '/users/un-subscribe/:email', to: 'users#un_subscribe'

  post '/mappings/loader', to: 'mappings#loader_process'
  get 'mappings/count/:id', to: 'mappings#count', constraints: { id: /.+/ }
  get 'mappings/show_mappings', to: 'mappings#show_mappings'
  get 'mappings/new', to: 'mappings#new'
  get 'mappings/:id', to: 'mappings#show', constraints: { id: /.+/ }
  post 'mappings/:id', to: 'mappings#update', constraints: { id: /.+/ }
  delete 'mappings/:id', to: 'mappings#destroy', constraints: { id: /.+/ }
  resources :mappings
  get 'mappings/:id', to: 'mappings#show', constraints: { id: /.+/ }

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
    get 'subject_chips', to: "ontologies#subject_chips"
  end

  # user ontologies
  resources :my_ontologies, only: [:index, :new]
  get '/user_ontologies_filter', to: 'my_ontologies#user_ontologies_filter'

  resources :ontologies do
    # TODO: reenable in the next releases
    # resource :administration, controller: 'ontologies_administration', only: [:show, :destroy] do
    #   get 'log'
    #   get 'submissions'
    #   delete 'submissions', action: :destroy_submission
    #   delete 'submissions/:id', action: :destroy_submission
    # end

    resources :submissions do
      get 'edit_properties'
    end

    get 'metrics'
    get 'metrics_evolution'
    get 'subscriptions'
  end



  resources :login

  resources :admin, only: [:index]

  namespace :admin do
    resources :licenses, only: [:index, :create, :new]
    match 'groups/synchronize_groups' => 'groups#synchronize_groups', via: [:post]
    resources :groups, only: [:index, :create, :new, :edit, :update, :destroy]
    resources :categories, only: [:index, :create, :new, :edit, :update, :destroy]
    resources :agents, only: [:index]
    resource :catalog_configuration, only: [:show, :update], controller: 'catalog_configuration'
    get 'catalog_configuration/edit_nested_form/:key', to: 'catalog_configuration#edit_nested_form', as: 'edit_nested_form_catalog_configuration'
    scope :search do
      get '/', to: 'search#index'
      post 'index_batch', to: 'search#index_batch'
      post ':collection/init_schema', to: 'search#init_schema'
      get ':collection/schema', to: 'search#show'
      get ':collection/data', to: 'search#search'
    end
    resources :analytics, only: [:index]
    constraints lambda { |request| request.session[:user]&.admin? } do
      mount Flipper::UI.app(Flipper) => '/flipper', as: :flipper
    end
  end

  post 'admin/clearcache', to: 'admin#clearcache'
  post 'admin/resetcache', to: 'admin#resetcache'
  post 'admin/clear_goo_cache', to: 'admin#clear_goo_cache'
  post 'admin/clear_http_cache', to: 'admin#clear_http_cache'
  get 'metadata_administration', to: 'admin#metadata_administration'
  get 'admin/ontologies_report', to: 'admin#ontologies_report'
  post 'admin/refresh_ontologies_report', to: 'admin#refresh_ontologies_report'
  delete 'admin/ontologies', to: 'admin#delete_ontologies'
  delete 'admin/ontologies/:acronym/submissions/:id', to: 'admin#delete_submission'
  put 'admin/ontologies', to: 'admin#process_ontologies'
  get 'admin/update_check_enabled', to: 'admin#update_check_enabled'
  get 'admin/ontologies/:acronym/log', to: 'admin#parse_log'

  resources :subscriptions

  resources :recommender

  get '/annotator', to: 'annotator#index'
  get '/annotatorplus', to: 'annotator#annotator_plus'
  get '/ncbo_annotatorplus', to: 'annotator#ncbo_annotator_plus'


  resources :virtual_appliance

  get 'change_requests/create_synonym'
  match 'change_requests', to: 'change_requests#create', via: :post

  # resource for metadata ontologies
  scope :ontologies_metadata_curator do
    post '/result', to: 'ontologies_metadata_curator#result'
    post '/edit', to: 'ontologies_metadata_curator#edit'
    put '/update', to: 'ontologies_metadata_curator#update'
    get '/:ontology/submissions/:submission_id/attributes/:attribute', to: 'ontologies_metadata_curator#show_metadata_value'
    get '/:ontology/submissions/:submission_id', to: 'ontologies_metadata_curator#show_metadata_by_ontology'
  end

  get '' => 'home#index'
  get 'home/metrics', to: 'home#metrics'
  get 'home/agents', to: 'home#agents'
  get 'status/:portal_name', to: 'home#federation_portals_status'
  
  # SPARQL 
  match 'sparql_proxy', to: 'admin#sparql_endpoint', via: [:get, :post]
  get 'sparql', to: 'sparql_endpoint#index', as: 'sparql_endpoint'
  get 'sparql/edit_sample_queries', to: 'sparql_endpoint#edit_sample_queries', as: 'edit_sample_queries'



  # Top-level pages
  match '/feedback', to: 'home#feedback', via: [:get, :post]
  get '/account' => 'users#show'
  get '/site_config' => 'home#site_config'
  post '/annotator_recommender_form' => 'home#annotator_recommender_form'
  match '/visits', to: 'visits#index', via: :get
  get 'statistics/index'

  # Error pages
  match '/404', to: 'errors#not_found', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all

  # Robots.txt
  get '/robots.txt' => 'robots#index'

  # Ontologies
  get '/ontologies/view/edit/:id' => 'ontologies#edit_view', :constraints => { id: /[^\/?]+/ }
  get '/ontologies/view/new/:id' => 'ontologies#new_view'
  get '/ontologies/:acronym/download' => 'ontologies_redirection#redirect_ontology'
  get '/ontologies/:acronym/:id/serialize/:output_format' => 'ontologies#content_serializer', :id => /.+/
  get '/ontologies/:acronym/htaccess' => 'ontologies_redirection#generate_htaccess'

  get '/ontologies/success/:id' => 'ontologies#submit_success'
  match '/ontologies/:acronym' => 'ontologies#update', via: [:get, :post]
  match '/ontologies/:acronym/submissions/:id' => 'submissions#update', via: [:get, :post]
  get '/ontologies/:ontology_id/submissions/new' => 'submissions#new', :ontology_id => /.+/
  match '/ontologies/:ontology_id/submissions' => 'submissions#create', :ontology_id => /.+/, via: [:post]
  match '/ontologies/:ontology_id/submissions' => 'submissions#index', :ontology_id => /.+/, via: [:get]
  get '/ontologies/:acronym/classes/:purl_conceptid', to: 'ontologies#show', constraints: { purl_conceptid: /[^\/]+/ }
  match '/ontologies/:acronym/submissions/:id/edit_metadata' => 'submissions#edit_metadata', via: [:get, :post]
  get '/ontologies_filter', to: 'ontologies#ontologies_filter'


  get 'ontologies_selector', to: 'ontologies#ontologies_selector'
  get 'ontologies_selector/results', to: 'ontologies#ontologies_selector_results'

  # Notes
  get 'ontologies/:ontology/notes/:noteid', to: 'notes#virtual_show', as: :note_virtual, noteid: /.+/
  get 'ontologies/:ontology/notes', to: 'notes#virtual_show'

  get '/ontologies/:acronym/:id' => 'ontologies_redirection#redirect', :id => /.+/

  # Ajax
  get '/ajax/class_details' => 'concepts#details'
  get '/ajax/mappings/get_concept_table' => 'mappings#get_concept_table'
  get '/ajax/notes/delete' => 'notes#destroy'
  get '/ajax/classes/label' => 'concepts#show_label'
  get '/ajax/classes/definition' => 'concepts#show_definition'
  get '/ajax/classes/treeview' => 'concepts#show_tree'
  get '/ajax/classes/list' => 'collections#show_members'
  get '/ajax/classes/date_sorted_list' => 'concepts#show_date_sorted_list'
  get '/ajax/properties/children' => 'properties#show_children'
  get '/ajax/properties/tree' => 'concepts#property_tree'
  get 'ajax/schemes/label', to: 'schemes#show_label'
  get 'ajax/collections/label', to: 'collections#show_label'
  get 'ajax/label_xl/label', to: 'label_xl#show_label'
  get 'ajax/label_xl', to: 'label_xl#show'
  get '/ajax/biomixer' => 'concepts#biomixer'
  get '/ajax/fair_score/html' => 'fair_score#details_html'
  get '/ajax/submission/show_licenses/:id' => 'ontologies#show_licenses'
  get '/ajax/fair_score/json' => 'fair_score#details_json'
  get '/ajax/fair_score/foops_json' => 'fair_score#foops_json'
  get '/ajax/ontologies', to: 'ontologies#ajax_ontologies'
  get '/ajax/agents', to: 'agents#ajax_agents'
  get '/ajax/agents/list', to: 'agents#ajax_agents_list'
  get '/ajax/images/show' => 'application#show_image_modal'

  # User
  get '/logout' => 'login#destroy', :as => :logout
  get '/lost_pass' => 'login#lost_password'
  get '/lost_pass_success' => 'login#lost_password_success'
  get '/reset_password' => 'login#reset_password'
  post '/accounts/:id/custom_ontologies' => 'users#custom_ontologies', :as => :custom_ontologies
  get '/login_as/:login_as' => 'login#login_as', constraints: { login_as: /[\d\w\.\@\-\%\+ ]+/ }
  post '/login/send_pass', to: 'login#send_pass'

  get '/groups' => 'taxonomy#index'
  get '/categories' => 'taxonomy#index'

  # Search
  get 'search', to: 'search#index'
  get 'search/json_search/:id', to: 'search#json_search'
  get 'ajax/search/ontologies/content', to: 'search#json_ontology_content_search'
  get 'ajax/search/ontologies/:ontology_acronym/classes', to: 'search#json_ontology_classes_search'

  get 'check_resolvability' => 'check_resolvability#index'
  get 'check_url_resolvability' => 'check_resolvability#check_resolvability'

  # Install the default route as the lowest priority.
  get '/:controller(/:action(/:id))'

  mount Lookbook::Engine, at: '/lookbook'
end
