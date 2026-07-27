require "net/http"
require "uri"
require "yaml"

class KgRegistry
  REGISTRY_URL = ENV.fetch("KG_REGISTRY_URL", "https://kghub.org/kg-registry/registry/kgs.yml").freeze
  CACHE_KEY = "kg_registry:v1".freeze
  CACHE_TTL = 6.hours

  def self.all
    resources = Array(registry_data[:resources])
    resources.sort_by { |resource| resource[:name].to_s.downcase }
  end

  def self.find(id)
    return nil if id.blank?

    all.find { |resource| resource[:id].to_s == id.to_s }
  end

  def self.registry_data
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      load_registry
    end
  end

  def self.load_registry
    yaml = fetch_yaml
    data = YAML.safe_load(yaml, aliases: false) || {}
    symbolize_keys_deep(data)
  rescue StandardError => e
    Rails.logger.error("KG registry load failed: #{e.class}: #{e.message}")
    { resources: [] }
  end

  def self.fetch_yaml
    local_path = ENV["KG_REGISTRY_PATH"]
    if local_path.present? && File.exist?(local_path)
      return File.read(local_path)
    end

    fetch_url(REGISTRY_URL)
  end

  def self.fetch_url(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: 5, read_timeout: 15) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "BioPortal-Web-UI"
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise "KG registry fetch failed: #{response.code} #{response.message}"
      end

      response.body
    end
  end

  def self.symbolize_keys_deep(value)
    case value
    when Array
      value.map { |item| symbolize_keys_deep(item) }
    when Hash
      value.each_with_object({}) do |(k, v), acc|
        key = k.respond_to?(:to_sym) ? k.to_sym : k
        acc[key] = symbolize_keys_deep(v)
      end
    else
      value
    end
  end
end
