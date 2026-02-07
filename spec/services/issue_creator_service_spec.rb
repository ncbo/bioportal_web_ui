# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IssueCreatorService do
  describe '.call' do
    subject(:result) { described_class.call(params) }
    let(:issue)      { result[:issue] }

    let(:params) do
      {
        ont_acronym: 'STY',
        content: {
          title: 'test issue',
          body: 'lorem ipsum dolor sit amet'
        }
      }
    end

    it 'creates an issue with the expected attributes' do
      skip 'Requires GitHub credentials (kgcl:github_access_token in Rails credentials)' unless
        Rails.application.credentials.dig(:kgcl, :github_access_token).present?

      expect(issue).to include('id' => a_kind_of(String),
                               'createdAt' => a_kind_of(String),
                               'title' => params[:content][:title],
                               'bodyText' => params[:content][:body])
      expect(issue['id']).to be_present
      expect(issue['createdAt']).to be_present
    end

    context 'when a query fails' do
      params = { ont_acronym: 'STY', content: { title: nil, body: 'lorem ipsum dolor sit amet' } }

      it 'raises an error' do
        skip 'Requires GitHub credentials (kgcl:github_access_token in Rails credentials)' unless
          Rails.application.credentials.dig(:kgcl, :github_access_token).present?

        expect { IssueCreatorService.call(params) }.to raise_error IssueCreatorService::QueryError
      end
    end
  end

  after :all do
    # TODO: delete test issue
    #   Currently creating test issues in a personal repository:
    #   jvendett/bioportal-nigms-u2. The kgcl-change-request user can't have
    #   access rights to delete issues in a personal repository, even when
    #   when added as a collaborator (per GitHub's documentation). Would need
    #   to move test issue creation to a repository owned by an organization.

    # DeleteIssueMutation = GitHub::Client.parse <<-'GRAPHQL'
    #   mutation ($issueId: ID!) {
    #     deleteIssue(input: {issueId: $issueId}) {
    #       repository {
    #         id
    #       }
    #     }
    #   }
    # GRAPHQL
    # response = GitHub::Client.query(DeleteIssueMutation, variables: { issueId: issue['id'] })
  end
end
