# frozen_string_literal: true

$SITE = 'Testportal'
$HOSTNAME = 'testportal'
$UI_HOSTNAME = 'localhost'
$UI_URL = "http://#{$UI_HOSTNAME}:3000"

$API_KEY = ENV['API_KEY']
$REST_URL = ENV['API_URL']
$BIOMIXER_URL = ENV['BIOMIXER_URL']
$ANNOTATOR_URL = $PROXY_URL = ENV['ANNOTATOR_URL'].blank? ? "https://services.tesportal.lirmm.fr/annotator" : ENV['ANNOTATOR_URL']
$FAIRNESS_URL = ENV['FAIRNESS_URL']

# FOOPS! FAIR assessment endpoint.
$FOOPS_URL = ENV['FOOPS_URL'] || 'https://foops.linkeddata.es/assessOntology'
$AGENTS_ENABLED = ENV["AGENTS_ENABLED"].to_s.downcase == "true"
$SPARQL_ENDPOINT_URL = ENV['SPARQL_ENDPOINT_URL'] || nil

# Resource term
$RESOURCE_TERM = ENV['RESOURCE_TERM'] || 'ontology'

# config/initializers/omniauth_providers.rb
$OMNIAUTH_PROVIDERS = {
  github: {
    client_id: 'CLIENT_ID',
    client_secret: 'CLIENT_SECRET',
    icon: 'github.svg',
    enable: true
  },
  google: {
    strategy: :google_oauth2,
    client_id: 'CLIENT_ID',
    client_secret: 'CLIENT_SECRET',
    icon: 'google.svg',
    enable: true
  },
  orcid: {
    client_id: 'CLIENT_SECRET',
    client_secret: 'CLIENT_SECRET',
    icon: 'orcid.svg',
    enable: false
  },
  keycloak: {
    strategy: :keycloak_openid,
    client_id: 'YOUR_KEYCLOAK_CLIENT_ID',
    client_secret: 'YOUR_KEYCLOAK_CLIENT_SECRET',
    client_options: { site: 'KEYCLOAK_SITE', realm: 'KEYCLOAK_REALM' },
    name: 'keycloak',
    icon: 'keycloak.svg',
    enable: false
  }
}.freeze

$INTERPORTAL_HASH = {}

# If your BioPortal installation includes Fairness score set this to true
$FAIRNESS_DISABLED = false

# Pairing a name with an array of ontology virtual ids will allow you to filter ontologies based on a subdomain.
# If your main UI is hosted at example.org and you add custom.example.org pointing to the same Rails installation
# you could filter the ontologies visible at custom.example.org by adding this to the hash: "custom" => { :name => "Custom Slice", :ontologies => [1032, 1054, 1099] }
# Any number of slices can be added. Groups are added automatically using the group acronym as the subdomain.
$ENABLE_SLICES = false
$ONTOLOGY_SLICES = {}


$NOT_DOWNLOADABLE = {}
# Enable client request caching
$CLIENT_REQUEST_CACHING = true

# If you don't use Airbrake you can have exceptions emailed to the $ERROR_EMAIL address by setting this to 'true'
$EMAIL_EXCEPTIONS = false

# Announcements mailman mailing list REQUEST address, EX: list-request@lists.example.org
# NOTE: You must use the REQUEST address for the mailing list. ONLY WORKS WITH MAILMAN LISTS.
$ANNOUNCE_LIST ||= 'appliance-users-request@localhost'

# Email addresses used for sending notifications (errors, feedback, support)
$SUPPORT_EMAIL ||= 'support@localhost'
$ADMIN_EMAIL ||= 'admin@localhost'
$ERROR_EMAIL ||= 'errors@localhost'

# Custom BioPortal logging
require 'log'
$REMOTE_LOGGING = false

##
# Custom Ontology Details
# Custom details can be added on a per ontology basis using a key/value pair as columns of the details table
#
# Example:
# $ADDITIONAL_ONTOLOGY_DETAILS = { 1000 => { "Additional Detail" => "Text to be shown in the right-hand column." } }
##
$ADDITIONAL_ONTOLOGY_DETAILS = {}

# Site notice appears on all pages and remains closed indefinitely. Stored below as a hash with a unique key and a
#  EX: $SITE_NOTICE = { :unique_key => 'Put your message here (can include <a href="/link">html</a> if you use
$SITE_NOTICE = {}
################################
## AUTO-GENERATED DO NOT MODIFY
#################################

# Full string for site, EX: "NCBO BioPortal"
$ORG_SITE = $ORG.nil? || $ORG.empty? ? $SITE : "#{$ORG} #{$SITE}"

$PORTALS_INSTANCES = [
   {
    name: 'AgroPortal',
    api: 'https://data.agroportal.eu',
    ui: 'https://agroportal.eu/',
    color: '#3CB371',
    apikey: '1de0a270-29c5-4dda-b043-7c3580628cd5',
    'light-color': '#F1F6FA',
  },
  {
    name: 'BioPortal',
    ui: 'https://bioportal.bioontology.org/',
    api: 'https://data.bioontology.org/',
    apikey: '8b5b7825-538d-40e0-9e9e-5ab9274a9aeb',
    color: '#234979',
    'light-color': '#E9F2FA',
  },
  {
    name: 'SIFR BioPortal',
    ui: 'https://bioportal.lirmm.fr/',
    api: 'https://data.bioportal.lirmm.fr/',
    apikey: '1de0a270-29c5-4dda-b043-7c3580628cd5',
    color: '#74a9cb',
    'light-color': '#E9F2FA',
  },
  {
    name: 'EcoPortal',
    ui: 'https://ecoportal.lifewatch.eu/',
    api: 'https://data.ecoportal.lifewatch.eu/',
    apikey: "43a437ba-a437-4bf0-affd-ab520e584719",
    color: '#2076C9',
    'light-color': '#E9F2FA',
  },
  {
    name: 'MedPortal',
    ui: 'http://medportal.bmicc.cn/',
    color: '#234979',
  },
  {
    name: 'MatPortal',
    ui: 'https://matportal.org/',
    color: '#009574',
  },
  {
    name: 'IndustryPortal',
    ui: 'http://industryportal.enit.fr',
    api: 'https://data.industryportal.enit.fr/',
    apikey: '019adb70-1d64-41b7-8f6e-8f7e5eb54942',
    color: '#1c0f5d',
    'light-color': '#F0F5F6',
  },
  {
    name: 'EarthPortal',
    ui: 'https://earthportal.eu/',
    api: 'https://data.earthportal.eu/',
    apikey: "c9147279-954f-41bd-b068-da9b0c441288",
    color: '#404696',
    'light-color': '#F0F5F6'
  },
  {
    name: 'BiodivPortal',
    ui: 'https://biodivportal.gfbio.org/',
    api: 'https://data.biodivportal.gfbio.org/',
    apikey: "47a57aa3-7b54-4f34-b695-dbb5f5b7363e",
    color: '#349696',
    'light-color': '#EBF5F5',
  },
  {
    name: 'testportal-down',
    ui: 'https://down.testportal.lirmm.fr/',
    api: 'https://down.testportal.lirmm.fr/',
    apikey: "47a57aa3-7b54-4f34-b695-dbb5f5b7363e",
  }
]

$FOOTER_LINKS = {
  social: [
    { logo: 'social/people.svg', link: 'https://github.com/orgs/agroportal/people' },
    { logo: 'social/github.svg', link: 'https://github.com/agroportal' },
    { logo: 'social/twitter.svg', link: 'https://twitter.com/lagroportal' }
  ],
  sections: {
    products: {
      ontoportal: 'https://ontoportal.org/',
      release_notes: 'https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/release-notes-btKjZk5tU2',
      api: 'https://data.agroportal.lirmm.fr/',
      sparql: 'https://sparql.agroportal.lirmm.fr/test/'
    },
    support: {
      contact_us: 'https://agroportal.lirmm.fr/feedback',
      wiki: 'https://www.bioontology.org/wiki/',
      documentation: 'https://ontoportal.github.io/documentation/'
    },
    agreements: {
      terms: '',
      privacy_policy: '',
      cite_us: '',
      acknowledgments: ''
    },
    about: {
      about_us: 'https://github.com/agroportal/project-management',
      projects: 'https://d2kab.mystrikingly.com/',
      team: 'https://github.com/orgs/agroportal/people'
    }
  }
}

$UI_THEME = :stageportal
