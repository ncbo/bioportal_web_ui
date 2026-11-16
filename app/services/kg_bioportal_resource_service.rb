# frozen_string_literal: true

require 'net/http'

# Returns the URL of an ontology's KG-BioPortal resource page, or nil when it has
# none (#552). KG-BioPortal publishes one page per ontology it knows about and a
# 404 for the rest, so the page's existence is what makes an ontology eligible
# for a link. The answer is cached so the ontology viewer doesn't call out on
# every request.
class KgBioportalResourceService < ApplicationService
  EXPIRY_ANSWERED = 24.hours
  # A timeout or server error isn't an answer; retry sooner.
  EXPIRY_UNANSWERED = 10.minutes
  TIMEOUT_SECONDS = 2

  # The base URL comes from links.kg_bioportal in config/settings.yml. Environments
  # that don't set it (e.g. the appliance) get no link.
  def initialize(acronym, base_url: Rails.configuration.settings.dig(:links, :kg_bioportal))
    @acronym = acronym.to_s
    @base_url = base_url
  end

  def call
    return if @base_url.blank? || @acronym.blank?

    url if page_exists?
  end

  private

  def url
    "#{@base_url.chomp('/')}/#{ERB::Util.url_encode(@acronym)}/"
  end

  def page_exists?
    cache_key = "kg_bioportal_resource/#{url}"
    cached = Rails.cache.read(cache_key)
    return cached unless cached.nil?

    exists = request_page
    Rails.cache.write(cache_key, exists == true, expires_in: exists.nil? ? EXPIRY_UNANSWERED : EXPIRY_ANSWERED)
    exists == true
  end

  # true when the page exists, false when it doesn't, nil when we couldn't tell.
  def request_page
    uri = URI.parse(url)
    options = { use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS }
    response = Net::HTTP.start(uri.host, uri.port, **options) { |http| http.head(uri.request_uri) }

    case response
    when Net::HTTPSuccess then true
    when Net::HTTPNotFound then false
    end
  rescue StandardError => e
    Rails.logger.warn("KG-BioPortal lookup failed for #{@acronym}: #{e.class}: #{e.message}")
    nil
  end
end
