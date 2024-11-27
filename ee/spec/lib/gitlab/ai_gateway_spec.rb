# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::AiGateway, feature_category: :cloud_connector do
  let(:ai_setting) { Ai::Setting.instance }
  let(:url) { 'http://ai-gateway.example.com:5052' }

  describe '.url' do
    context 'when ai_gateway_url setting is set' do
      it 'returns the setting value' do
        ai_setting.update!(ai_gateway_url: url)

        expect(described_class.url).to eq(url)
      end
    end

    context 'when ai_gateway_url setting is not set' do
      before do
        ai_setting.update!(ai_gateway_url: nil)
      end

      context 'when AI_GATEWAY_URL environment variable is set' do
        it 'returns the env var' do
          stub_env('AI_GATEWAY_URL', url)

          expect(described_class.url).to eq(url)
        end
      end

      context 'when AI_GATEWAY_URL is not set' do
        it 'returns the cloud connector url' do
          allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

          expect(described_class.cloud_connector_url).to eq("#{url}/ai")
        end
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
    context 'when the ai_gateway_url setting is set' do
      it 'returns the the setting value' do
        ai_setting.update!(ai_gateway_url: url)
        stub_env('AI_GATEWAY_URL', nil)

        expect(described_class.self_hosted_url).to eq(url)
      end
    end

    context 'when the ai_gateway_url setting is not set' do
      it 'returns the AI_GATEWAY_URL env var value' do
        ai_setting.update!(ai_gateway_url: nil)
        stub_env('AI_GATEWAY_URL', url)

        expect(described_class.self_hosted_url).to eq(url)
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
    let(:service_name) { :test }
    let(:service) { instance_double(CloudConnector::BaseAvailableServiceData, name: service_name) }
    let(:agent) { nil }
    let(:lsp_version) { nil }
    let(:cloud_connector_headers) do
      {
        'X-Gitlab-Host-Name' => 'hostname',
        'X-Gitlab-Instance-Id' => 'ABCDEF',
        'X-Gitlab-Global-User-Id' => '123ABC',
        'X-Gitlab-Realm' => 'self-managed',
        'X-Gitlab-Version' => '17.1.0',
        'X-Gitlab-Duo-Seat-Count' => "50"
      }
    end

    let(:expected_headers) do
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{token}",
        'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '1,2',
        'Content-Type' => 'application/json',
        'X-Request-ID' => an_instance_of(String),
        'X-Gitlab-Rails-Send-Start' => an_instance_of(String),
        'x-gitlab-enabled-feature-flags' => an_instance_of(String)
      }.merge(cloud_connector_headers)
    end

    subject(:headers) { described_class.headers(user: user, service: service, agent: agent, lsp_version: lsp_version) }

    before do
      allow(service).to receive(:access_token).with(user).and_return(token)
      allow(user).to receive(:allowed_by_namespace_ids).with(service_name).and_return(enabled_by_namespace_ids)
      allow(::CloudConnector).to(
        receive(:ai_headers).with(user, namespace_ids: enabled_by_namespace_ids).and_return(cloud_connector_headers)
      )
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

    context 'when there is no user' do
      let(:user) { nil }
      let(:enabled_by_namespace_ids) { [] }

      it { is_expected.to match(expected_headers.merge('X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '')) }
    end
  end

  describe '.public_headers' do
    let(:user) { build(:user, id: 1) }
    let(:service_name) { :test }
    let(:service) { instance_double(CloudConnector::BaseAvailableServiceData, name: service_name) }
    let(:namespace_ids) { [1, 2, 3] }
    let(:enabled_feature_flags) { %w[feature_a feature_b] }
    let(:ai_headers) { { 'X-Gitlab-Duo-Seat-Count' => 1, 'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '' } }

    subject(:public_headers) { described_class.public_headers(user: user, service: service) }

    before do
      allow(user).to receive(:allowed_by_namespace_ids)
        .with(service)
        .and_return(namespace_ids)

      allow(described_class).to receive(:enabled_feature_flags)
        .and_return(enabled_feature_flags)

      allow(::CloudConnector).to receive(:ai_headers)
        .with(user, namespace_ids: namespace_ids)
        .and_return(ai_headers)
    end

    it 'returns headers with enabled feature flags and AI headers' do
      expected_headers = {
        'X-Gitlab-Duo-Seat-Count' => 1,
        'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '',
        'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b'
      }

      expect(public_headers).to eq(expected_headers)
    end

    context 'when there are no enabled feature flags' do
      let(:enabled_feature_flags) { [] }

      it 'returns headers with empty feature flags string' do
        expected_headers = {
          'X-Gitlab-Duo-Seat-Count' => 1,
          'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '',
          'x-gitlab-enabled-feature-flags' => ''
        }

        expect(public_headers).to eq(expected_headers)
      end
    end

    context 'when there are duplicate feature flags' do
      let(:enabled_feature_flags) { %w[feature_a feature_a feature_b] }

      it 'returns headers with unique feature flags' do
        expected_headers = {
          'X-Gitlab-Duo-Seat-Count' => 1,
          'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => '',
          'x-gitlab-enabled-feature-flags' => 'feature_a,feature_b'
        }

        expect(public_headers).to eq(expected_headers)
      end
    end
  end
end
