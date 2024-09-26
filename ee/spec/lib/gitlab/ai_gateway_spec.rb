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

  describe '.cloud_connector_url' do
    context 'when AI_GATEWAY_URL environment variable is not set' do
      let(:url) { 'http:://example.com' }

      it 'returns the cloud connector url' do
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

        expect(described_class.cloud_connector_url).to eq("#{url}/ai")
      end
    end
  end

  describe '.self_hosted_url' do
    context 'when AI_GATEWAY_URL environment variable is set' do
      let(:url) { 'http://localhost:5052' }

      it 'returns the url' do
        stub_env('AI_GATEWAY_URL', url)

        expect(described_class.self_hosted_url).to eq(url)
      end
    end

    context 'when AI_GATEWAY_URL environment variable is not set' do
      it 'returns nil' do
        stub_env('AI_GATEWAY_URL', nil)

        expect(described_class.self_hosted_url).to be_nil
      end
    end
  end

  describe '.push_feature_flag', :request_store do
    before do
      allow(::Feature).to receive(:enabled?).and_return(true)
    end

    it 'push feature flag' do
      described_class.push_feature_flag("feature_a")
      described_class.push_feature_flag("feature_b")
      described_class.push_feature_flag("feature_c")

      expect(described_class.enabled_feature_flags).to match_array(%w[feature_a feature_b feature_c])
    end
  end

  describe '.enabled_feature_flags', :request_store do
    it 'returns empty' do
      expect(described_class.enabled_feature_flags).to eq([])
    end
  end

  describe '.headers' do
    let(:user) { build(:user, id: 1) }
    let(:token) { 'instance token' }
    let(:enabled_by_namespace_ids) { [1, 2] }
    let(:service) { instance_double(CloudConnector::BaseAvailableServiceData) }
    let(:agent) { nil }
    let(:lsp_version) { nil }
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
        'X-Gitlab-Duo-Seat-Count' => "0",
        'x-gitlab-enabled-feature-flags' => an_instance_of(String)
      }
    end

    subject(:headers) { described_class.headers(user: user, service: service, agent: agent, lsp_version: lsp_version) }

    before do
      allow(service).to receive(:access_token).with(user).and_return(token)
      allow(service).to receive(:enabled_by_namespace_ids).with(user).and_return(enabled_by_namespace_ids)
    end

    it { is_expected.to match(expected_headers) }

    context 'when agent is set' do
      let(:agent) { 'user agent' }

      it { is_expected.to match(expected_headers.merge('User-Agent' => agent)) }
    end

    context 'when lsp_version is set' do
      let(:lsp_version) { '4.21.0' }

      it { is_expected.to match(expected_headers.merge('X-Gitlab-Language-Server-Version' => lsp_version)) }
    end

    context 'when Langsmith is enabled' do
      before do
        allow(Langsmith::RunHelpers).to receive(:enabled?).and_return(true)
        allow(Langsmith::RunHelpers).to receive(:to_headers).and_return({
          "langsmith-trace" => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        })
      end

      it 'includes langsmith header' do
        expect(headers).to include(
          'langsmith-trace' => '20240808T090953171943Z18dfa1db-1dfc-4a48-aaf8-a139960955ce'
        )
      end
    end

    context 'when feature flag is pushed' do
      before do
        allow(described_class).to receive(:enabled_feature_flags).and_return(%w[feature_a feature_b])
      end

      it 'includes feature flag header' do
        expect(headers).to include(
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b'
        )
      end
    end
  end
end
