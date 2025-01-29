#frozen_string_literal: true
require 'graphql/client'
require 'graphql/client/http'

module GitHub
  HTTPAdapter = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(_context)
      { 'Authorization': "Bearer #{Rails.application.credentials.dig(:kgcl, :github_access_token)}" }
    end
  end

  Client = GraphQL::Client.new(
    schema: File.join(Rails.root, 'data', 'schema.json').to_s,
    execute: HTTPAdapter
  )
end
