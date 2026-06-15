$DEBUG_API_CLIENT = true
$API_CLIENT_INVALIDATE_CACHE = true
$READ_ONLY_PORTAL = ENV["READ_ONLY_PORTAL"].to_s.downcase == "true"
$AGENTS_ENABLED = ENV["AGENTS_ENABLED"].to_s.downcase == "true"

# Organization info
$ORG = ENV['ORG']
$ORG_URL = ENV['ORG_URL']

# Site name (required)
$SITE = ENV['SITE']

# Twitter section
$TWITTER_NEWS = ENV["TWITTER_NEWS"]

# Full string for site, EX: "NCBO BioPortal", do not modify
$ORG_SITE = $ORG.nil? || $ORG.empty? ? $SITE : "#{$ORG} #{$SITE}"

# The URL for the BioPortal Rails UI (this application)
$UI_URL = ENV['UI_URL']

# If you are running a PURL server to provide URLs for ontologies in your BioPortal instance, enable this option
$PURL_ENABLED = false
# The PURL URL is generated using this prefix + the abbreviation for an ontology.
# The PURL URL generation algorithm can be altered in app/models/ontology_wrapper.rb
$PURL_PREFIX = 'http://purl.bioontology.org/ontology'

# Flipper::UI.configure do |config|
#   config.banner_text = 'Production Environment'
#   config.banner_class = 'danger'
# end

# If your BioPortal installation includes Annotator set this to false
$ANNOTATOR_DISABLED = false
# Unique string representing the UI's id for use with the BioPortal Core
$API_KEY = ENV['API_KEY']
# BioPortal API service address
$REST_URL = ENV['API_URL']


$SPARQL_ENDPOINT_URL = ENV['SPARQL_ENDPOINT_URL'] || nil

$SIDEKIQ_UI_URL = ENV['SIDEKIQ_UI_URL'] || $REST_URL + "sidekiq"
# Annotator REST service address
# $ANNOTATOR_URL = "http://services.stageportal.lirmm.fr/annotator"
$ANNOTATOR_URL = $PROXY_URL = ENV['ANNOTATOR_URL']
# NCBO annotator URL and apikey
$NCBO_ANNOTATORPLUS_ENABLED = ENV['NCBO_ANNOTATORPLUS_ENABLED']
$NCBO_ANNOTATOR_URL = ENV['NCBO_ANNOTATOR_URL']
$NCBO_API_KEY = ENV['NCBO_API_KEY']

# Fairness Assessment.
$FAIRNESS_DISABLED = ENV['FAIRNESS_DISABLED']
$FAIRNESS_URL = ENV['FAIRNESS_URL']

# FOOPS! FAIR assessment endpoint.
$FOOPS_URL = ENV['FOOPS_URL'] || 'https://foops.linkeddata.es/assessOntology'

# Used to define other bioportal that can be mapped to
# Example to map to ncbo bioportal : {"ncbo" => {"api" => "http://data.bioontology.org", "ui" => "http://bioportal.bioontology.org", "apikey" => ""}
# Then create the mapping using the following class in JSON : "http://purl.bioontology.org/ontology/MESH/C585345": "ncbo:MESH"
# Where "ncbo" is the namespace used as key in the interportal_hash
$INTERPORTAL_HASH = {}

$NOT_DOWNLOADABLE = {}

# Bugsnag API key for monitoring exception
#$BUGSNAG_API_KEY=

# OAuth2 authentication
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

# Don't load and don't display recent mappings if false, in case of too many mappings (take longer to load homepage)
$DISPLAY_RECENT = false

# If true then the UI will get available recognize at API_URL/annotators/recognizers
$MULTIPLE_RECOGNIZERS = false

# Remove download for these ontologies. Default:
# ["CPT","ICD10","ICNP","ICPC2P","MDDB","MEDDRA","MSHFRE","MSHSPA_1","NDDF","NDFRT","NIC","RCD","SCTSPA","SNOMEDCT","WHO-ART"]
$RESTRICTED_DOWNLOADS = []

# Legacy REST core service address (BioPortal v3.x and lower)
$LEGACY_REST_URL = 'http://example.org:8080/bioportal'

# Release version text (appears in footer of all pages, except 404 and 500 errors)
$RELEASE_VERSION = ENV['RELEASE_VERSION']

# Enable Slices, filtering of ontologies based on subdomain and ontology groups
$ENABLE_SLICES = false

# Google Analytics ID (optional)
$ANALYTICS_ID = ENV['ANALYTICS_ID']

# Enable client request caching
$CLIENT_REQUEST_CACHING = true

# Email settings
ActionMailer::Base.smtp_settings = {
  address: '', # smtp server address, ex: smtp.example.org
  port: 25, # smtp server port
  domain: '' # fqdn of rails server, ex: rails.example.org
}
# Announcements mailman mailing list REQUEST address, EX: list-request@lists.example.org
# NOTE: You must use the REQUEST address for the mailing list. ONLY WORKS WITH MAILMAN LISTS.
$ANNOUNCE_LIST = ENV['SUPPORT_EMAIL']
# Email addresses used for sending notifications (errors, feedback, support)
$SUPPORT_EMAIL = ENV['SUPPORT_EMAIL']
# Email used to send notifications
$NOTIFICATION_EMAIL = ENV['SUPPORT_EMAIL']



# reCAPTCHA
# In order to use reCAPTCHA on the account creation and feedback submission pages:
#    1. Obtain a reCAPTCHA v2 key from: https://www.google.com/recaptcha/admin
#    2. Put the site and secret keys in the encrypted credentials file:
#
#       recaptcha:
#         site_key: your_site_key
#         secret_key: your_secret_key
#
#    3. Set the USE_RECAPTCHA option to 'true'
ENV['USE_RECAPTCHA'] = 'false'
# Custom BioPortal logging
require 'log'

# URL where BioMixer GWT app is located
# $BIOMIXER_URL = "http://bioportal-integration.bio-mixer.appspot.com"
$BIOMIXER_URL = ENV['BIOMIXER_URL']
$BIOMIXER_APIKEY = ENV['BIOMIXER_APIKEY']

##
# Custom Ontology Details
# Custom details can be added on a per ontology basis using a key/value pair as columns of the details table
#
# Example:
# $ADDITIONAL_ONTOLOGY_DETAILS = { "STY" => { "Additional Detail" => "Text to be shown in the right-hand column." } }
##
$ADDITIONAL_ONTOLOGY_DETAILS = {}

# Front notice appears on the front page only and is closable by the user. It remains closed for seven days (stored in cookie)
$FRONT_NOTICE = ''
# Site notice appears on all pages and remains closed indefinitely. Stored below as a hash with a unique key and a string message
# EX: $SITE_NOTICE = { :unique_key => 'Put your message here (can include <a href="/link">html</a> if you use single quotes).' }
$SITE_NOTICE = {}

$TERMS_AND_CONDITIONS_LINK = 'https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/terms-conditions-naDsDo2Zxq'
$CITE_ANNOTATOR = 'https://hal.science/hal-00492024'
$ANNOTATOR_API_DOC = 'https://data.agroportal.lirmm.fr/documentation#nav_annotator'
$CITE_RECOMMENDER = 'https://doi.org/10.1186/s13326-017-0128-y' 
# Resource term
$RESOURCE_TERM = ENV['RESOURCE_TERM'] || 'ontology'

$HOME_PAGE_LOGOS = [
    {
      img_src: 'logos/supports/numev.webp',
      url: 'http://www.lirmm.fr/numev',
      target: '_blank'
    },
    {
      img_src: 'logos/supports/anr.webp',
      url: 'https://anr.fr/en',
      target: '_blank'
    },
    {
      img_src: 'logos/supports/eu.webp',
      url: 'https://commission.europa.eu/research-and-innovation_en',
      target: '_blank'
    },
    {
      img_src: 'logos/collaboration/d2kab.webp',
      url: 'http://d2kab.mystrikingly.com',
      target: '_blank'
    },
    {
      img_src: 'logos/collaboration/um_logo.webp',
      url: 'https://www.umontpellier.fr/',
      target: '_blank',
    },
    {
      img_src: 'logos/collaboration/inrae.webp',
      url: 'https://www.inrae.fr/enm',
      target: '_blank'
    },
    {
      img_src: 'logos/collaboration/stanford.webp',
      url: 'https://www.stanford.edu',
      target: '_blank'
    },
    {
      img_src: 'logos/collaboration/ontoportal.webp',
      url: 'https://ontoportal.org/',
      target: '_blank',
    }
]

$PORTALS_INSTANCES = [
  {
    name: 'AgroPortal',
    api: 'https://data.agroportal.lirmm.fr',
    ui: 'https://agroportal.lirmm.fr/',
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
    name: 'TestPortal',
    ui: 'https://testportal.lirmm.fr/',
    api: 'https://data.testportal.lirmm.fr/',
    color: '#74a9cb',
    apikey: '1de0a270-29c5-4dda-b043-7c3580628cd5',
  },
  {
    name: 'BiodivPortal',
    ui: 'https://biodivportal.gfbio.org/',
    api: 'https://data.biodivportal.gfbio.org/',
    apikey: "47a57aa3-7b54-4f34-b695-dbb5f5b7363e",
    color: '#349696',
    'light-color': '#EBF5F5',
  }
]


$ONTOPORTAL_WEBSITE_LINK = "https://ontoportal.org/"
$ONTOPORTAL_GITHUB_REPO = "https://github.com/ontoportal"

$GITHUB_ISSUES = "https://github.com/agroportal/project-management/issues"
$FOOTER_LINKS = {
  social: [
    { logo: "social/people.svg", link: "https://github.com/orgs/agroportal/people" },
    { logo: "social/github.svg", link: "https://github.com/agroportal" },
    { logo: "social/twitter.svg", link: "https://twitter.com/lagroportal" },
    { logo: "json.svg", link: $REST_URL },
    { logo: "summary/sparql.svg", link: "#{$SPARQL_URL}"},
    { logo: "social/email.svg", link: "mailto:#{$ANNOUNCE_LIST}" },
  ],
  sections: {
    products: {
      release_notes: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/release-notes-btKjZk5tU2",
      api: "https://data.agroportal.lirmm.fr/",
      tools: "/tools",
      sparql: "https://sparql.agroportal.lirmm.fr/test/",
      ontoportal: $ONTOPORTAL_WEBSITE_LINK
    },
    support: {
      contact_us: "https://#{$SITE}.lirmm.fr/feedback",
      documentation: "https://ontoportal.github.io/documentation/",
      agro_documentation: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/public-documentation-QMpsC9aVBb",
      issues_and_requests: $GITHUB_ISSUES 
    },
    agreements: {
      terms: $TERMS_AND_CONDITIONS_LINK,
      privacy_policy: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/terms-conditions-naDsDo2Zxq",
      legal_notices: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/terms-conditions-naDsDo2Zxq"
    },
    about: {
      about_us: "https://github.com/agroportal/project-management",
      team: "https://github.com/orgs/agroportal/people",
      cite_us: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/publications-and-references-87tEoeoGKy",
      acknowledgments: "https://doc.jonquetlab.lirmm.fr/share/e6158eda-c109-4385-852c-51a42de9a412/doc/acknowledgments-15GdRXLQdm"
    }
  }
}



# Monitoring
$SENTERY_DSN = ENV['SENTRY_DSN'] # if you want to use sentery.io
$NEW_RELIC_LICENSE_KEY = ENV['NEW_RELIC_LICENSE_KEY'] # if you want to use newrelic.io

$UI_THEME = ENV['UI_THEME'] || 'ontoportal'
$HOSTNAME = ENV['API_URL']

if $HOSTNAME
  $HOSTNAME = ENV['API_URL'].split('data.').last
  # add custom stage server configuration if needed (e.g bioportal_config_development_stageportal.lirmm.fr)
  if File.exist?("config/bioportal_config_development_#{$HOSTNAME}")
    require_relative "bioportal_config_development_#{$HOSTNAME}"
  end
end
