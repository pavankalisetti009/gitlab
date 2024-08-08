# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::AiGateway, feature_category: :cloud_connector do
  describe '.url' do
    context 'when AI_GATEWAY_URL environment variable is set' do
      let(:url) { 'http://localhost:5052' }

      it 'returns the AI_GATEWAY_URL' do
        stub_env('AI_GATEWAY_URL', url)

        expect(described_class.url).to eq(url)
      end
    end

    context 'when AI_GATEWAY_URL environment variable is not set' do
      let(:url) { 'http:://example.com' }

      it 'returns the cloud connector url' do
        stub_env('AI_GATEWAY_URL', nil)
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

        expect(described_class.url).to eq("#{url}/ai")
      end
    end
  end

  describe '.headers' do
    let(:user) { build(:user, id: 1) }
    let(:token) { 'instance token' }
    let(:enabled_by_namespace_ids) { [1, 2] }
    let(:service) { instance_double(CloudConnector::BaseAvailableServiceData) }
    let(:agent) { nil }
    let(:expected_headers) do
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{token}",
        'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '1,2',
        'Content-Type' => 'application/json',
        'X-Request-ID' => an_instance_of(String),
        'X-Gitlab-Rails-Send-Start' => an_instance_of(String),
        'X-Gitlab-Global-User-Id' => an_instance_of(String),
        'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
        'X-Gitlab-Instance-Id' => an_instance_of(String),
        'X-Gitlab-Realm' => Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'X-Gitlab-Version' => Gitlab.version_info.to_s,
        'X-Gitlab-Duo-Seat-Count' => "0"
      }
    end

    subject(:headers) { described_class.headers(user: user, service: service, agent: agent) }

    before do
      allow(service).to receive(:access_token).with(user).and_return(token)
      allow(service).to receive(:enabled_by_namespace_ids).with(user).and_return(enabled_by_namespace_ids)
    end

    it { is_expected.to match(expected_headers) }

    context 'when agent is set' do
      let(:agent) { 'user agent' }

      it { is_expected.to match(expected_headers.merge('User-Agent' => agent)) }
    end
  end
end
