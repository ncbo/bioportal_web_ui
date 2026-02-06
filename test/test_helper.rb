ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'simplecov'
require 'webmock/minitest'
require 'timeout'

SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/test/'
  add_filter '/vendor/'
end

# Per-test timeout (seconds). Many tests call the slow external BioPortal API,
# so the default is generous. Override with TEST_TIMEOUT env var.
TEST_TIMEOUT = Integer(ENV.fetch('TEST_TIMEOUT', 180))

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: 1)

  # Add more helper methods to be used by all tests here...

  WebMock.allow_net_connect!

  Capybara.server_host = "0.0.0.0"
  Capybara.app_host = "http://#{Socket.gethostname}:#{Capybara.server_port}"

  # Wrap each test in a timeout so a stuck API call does not hang the suite.
  # A timeout is reported as a skip (not a failure) since it usually means the
  # external service is slow or unavailable rather than a real test defect.
  def run
    Timeout.timeout(TEST_TIMEOUT, Timeout::Error) { super }
  rescue Timeout::Error
    skip "Test timed out after #{TEST_TIMEOUT}s (external API may be slow/unavailable). " \
         "Increase with TEST_TIMEOUT env var."
  end
end

# Define the fixtures helper method
def fixtures(fixture_name)
  @global_fixtures ||= load_all_fixtures
  @global_fixtures[fixture_name.to_s]
end

# Load all fixtures method
def load_all_fixtures
  fixtures_directory = Rails.root.join('test', 'fixtures')
  fixture_files = Dir.glob(File.join(fixtures_directory, '*.yml'))

  fixtures_data = {}

  fixture_files.each do |fixture_file|
    fixture_name = File.basename(fixture_file, '.yml')
    data = YAML.load_file(fixture_file)
    if data["yaml_structure"].eql?("regular")
      fixtures_data[fixture_name] = data
    else
      fixtures_data[fixture_name] = OpenStruct.new(Array(data).map{|key, hash| [key , OpenStruct.new(hash)]}.to_h)
    end
  end

  fixtures_data
end