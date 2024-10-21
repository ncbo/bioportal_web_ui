ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'simplecov'
require 'webmock/minitest'

SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/test/'
  add_filter '/vendor/'
end

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: 1)

  # Add more helper methods to be used by all tests here...

  WebMock.allow_net_connect!

  Capybara.server_host = "0.0.0.0"
  Capybara.app_host = "http://#{Socket.gethostname}:#{Capybara.server_port}"
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