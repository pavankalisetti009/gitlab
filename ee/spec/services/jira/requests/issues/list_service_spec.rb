# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jira::Requests::Issues::ListService, feature_category: :integrations do
  include AfterNextHelpers

  let(:jira_integration) { create(:jira_integration) }
  let(:params) { {} }

  describe '#execute' do
    let(:integration) { described_class.new(jira_integration, params) }

    subject { integration.execute }

    context 'without jira_integration' do
      before do
        jira_integration.update!(active: false)
      end

      it 'returns an error response' do
        expect(subject.error?).to be_truthy
        expect(subject.message).to eq('Jira service not configured.')
      end
    end

    context 'when jira_integration is nil' do
      let(:jira_integration) { nil }

      it 'returns an error response' do
        expect(subject.error?).to be_truthy
        expect(subject.message).to eq('Jira service not configured.')
      end
    end

    context 'with jira_integration' do
      context 'when validations and params are ok' do
        let(:jira_integration) { create(:jira_integration, url: 'https://jira.example.com') }
        let(:response_body) { '' }
        let(:response_headers) { { 'content-type' => 'application/json' } }
        let(:expected_url_pattern) { %r{.*jira.example.com/rest/api/3/search/jql.*} }

        before do
          stub_request(:get, expected_url_pattern).to_return(status: 200, body: response_body, headers: response_headers)
        end

        it_behaves_like 'a service that handles Jira API errors'

        context 'when jira runs on a subpath' do
          let(:jira_integration) { create(:jira_integration, url: 'http://jira.example.com/jira') }
          let(:expected_url_pattern) { %r{.*jira.example.com/jira/rest/api/3/search/jql.*} }

          it 'takes the subpath into account' do
            expect(subject.success?).to be_truthy
          end
        end

        context 'when the request does not return any values' do
          let(:response_body) { { issues: [] }.to_json }

          it 'returns a payload with no issues' do
            payload = subject.payload

            expect(subject.success?).to be_truthy
            expect(payload[:issues]).to be_empty
            expect(payload[:is_last]).to be_truthy
            expect(payload[:next_page_token]).to be_nil
          end
        end

        context 'when the request returns values' do
          let(:response_body) do
            {
              issues: [{ key: 'TST-1' }, { key: 'TST-2' }],
              isLast: false,
              nextPageToken: 'abc123'
            }.to_json
          end

          it 'returns a payload with jira issues' do
            payload = subject.payload

            expect(subject.success?).to be_truthy
            expect(payload[:issues].map(&:key)).to eq(%w[TST-1 TST-2])
            expect(payload[:is_last]).to be_falsy
            expect(payload[:next_page_token]).to eq('abc123')
          end
        end

        context 'when using token-based pagination parameters' do
          let(:params) { { next_page_token: 'token123', per_page: 50 } }

          it 'includes next_page_token and per_page in the request' do
            expect_next(JIRA::Client).to receive(:get)
              .with(include('maxResults=50'))
              .with(include('nextPageToken=token123'))
              .and_return({ 'issues' => [] })

            subject
          end
        end

        context 'without pagination parameters' do
          let(:params) { {} }

          it 'uses the default per_page' do
            expect_next(JIRA::Client).to receive(:get)
              .with(include('maxResults=100'))
              .and_return({ 'issues' => [] })

            subject
          end

          it 'does not include nextPageToken when not provided' do
            expect_next(JIRA::Client).to receive(:get)
              .with(exclude('nextPageToken'))
              .and_return({ 'issues' => [] })

            subject
          end
        end

        it 'requests for default fields' do
          expect_next(JIRA::Client).to receive(:get)
            .with(include("fields=#{described_class::DEFAULT_FIELDS}"))
            .and_return({ 'issues' => [] })

          subject
        end

        it 'uses API version 3' do
          expect_next(JIRA::Client).to receive(:get)
            .with(include('/rest/api/3/'))
            .and_return({ 'issues' => [] })

          subject
        end

        context 'when isLast is true' do
          let(:response_body) do
            {
              issues: [{ key: 'TST-1' }],
              isLast: true
            }.to_json
          end

          it 'indicates this is the last page' do
            payload = subject.payload

            expect(payload[:is_last]).to be_truthy
            expect(payload[:next_page_token]).to be_nil
          end
        end
      end
    end
  end
end
