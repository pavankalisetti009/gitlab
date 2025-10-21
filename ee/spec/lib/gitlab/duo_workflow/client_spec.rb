# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DuoWorkflow::Client, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  before do
    stub_feature_flags(duo_agent_platform_enable_direct_http: false)
  end

  describe '.url_for' do
    subject(:url) { described_class.url_for(feature_setting: feature_setting, user: user) }

    let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }
    let(:cloud_connector_url) { 'cloud.gitlab.com:443' }

    before do
      ::Ai::Setting.instance.update!(duo_agent_platform_service_url: self_hosted_url)
      allow(described_class).to receive(:cloud_connected_url).and_return(cloud_connector_url)
    end

    context 'when feature setting is self-hosted' do
      let_it_be(:model) { create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219') }
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model) }

      it 'returns the self-hosted URL' do
        expect(url).to eq(self_hosted_url)
      end
    end

    context 'when feature setting is not self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, :duo_agent_platform, provider: :vendored) }

      it 'returns the cloud connector URL' do
        expect(url).to eq(cloud_connector_url)
      end
    end

    context 'when feature setting is nil' do
      let(:feature_setting) { nil }

      it 'returns the cloud connector URL' do
        expect(url).to eq(cloud_connector_url)
      end
    end
  end

  describe '.url' do
    subject(:url) { described_class.url(user: user) }

    it 'returns cloud connector URL' do
      expect(url).to eq("cloud.gitlab.com:443")
    end

    context 'with self-hosted URL' do
      let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }

      context 'when self-hosted URL is set' do
        before do
          ::Ai::Setting.instance.update!(duo_agent_platform_service_url: self_hosted_url)
        end

        it 'returns self-hosted URL' do
          expect(url).to eq(self_hosted_url)
        end

        context 'when config url is also set' do
          let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

          before do
            allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
          end

          it 'still returns self-hosted URL' do
            expect(url).to eq(self_hosted_url)
          end
        end
      end

      context 'when self-hosted URL is not set' do
        it 'returns cloud connector URL' do
          expect(url).to eq("cloud.gitlab.com:443")
        end
      end
    end

    context 'when url is set in config' do
      let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }

      before do
        allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      end

      it 'returns configured url' do
        expect(url).to eq(duo_workflow_service_url)
      end
    end

    context 'when duo_workflow_cloud_connector_url feature flag is disabled' do
      before do
        stub_feature_flags(duo_workflow_cloud_connector_url: false)
      end

      it 'returns url to Duo Workflow Service fleet' do
        expect(url).to eq('duo-workflow-svc.runway.gitlab.net:443')
      end

      context 'when cloud connector url is staging' do
        before do
          allow(::CloudConnector::Config).to receive(:host).and_return('cloud.staging.gitlab.com')
        end

        it 'returns url to staging Duo Workflow Service fleet' do
          expect(url).to eq('duo-workflow-svc.staging.runway.gitlab.net:443')
        end
      end
    end
  end

  describe '.headers' do
    it 'returns cloud connector headers' do
      expect(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })

      expect(described_class.headers(user: user)).to eq({ header_key: 'header_value' })
    end
  end

  describe '.secure?' do
    it 'returns secure config' do
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return true
      expect(described_class.secure?).to eq(true)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return false
      expect(described_class.secure?).to eq(false)
      allow(Gitlab.config.duo_workflow).to receive(:secure).and_return nil
      expect(described_class.secure?).to eq(false)
    end
  end

  describe '.cloud_connector_headers' do
    let(:token) { 'duo_workflow_token_123' }

    before do
      allow(::CloudConnector::Tokens).to receive(:get).and_return(token)
    end

    it 'returns headers with base URL, authorization, and authentication type' do
      expected_headers = {
        'authorization' => "Bearer #{token}",
        'x-gitlab-authentication-type' => 'oidc',
        'x-gitlab-feature-enabled-by-namespace-ids' => '',
        'x-gitlab-global-user-id' => Gitlab::GlobalAnonymousId.user_id(user),
        'x-gitlab-user-id' => user.id.to_s,
        'x-gitlab-host-name' => 'localhost',
        'x-gitlab-instance-id' => 'uuid-not-set',
        'x-gitlab-realm' => 'self-managed',
        'x-gitlab-version' => Gitlab.version_info.to_s,
        'x-gitlab-enabled-instance-verbose-ai-logs' => 'true',
        'x-gitlab-enabled-feature-flags' => '',
        'x-gitlab-feature-enablement-type' => ''
      }

      expect(described_class.cloud_connector_headers(user: user)).to eq(expected_headers)
    end

    context 'when duo_agent_platform_enable_direct_http is enabled' do
      it 'returns headers with x-gitlab-base-url' do
        stub_feature_flags(duo_agent_platform_enable_direct_http: true)

        expected_headers = {
          'authorization' => "Bearer #{token}",
          'x-gitlab-authentication-type' => 'oidc',
          'x-gitlab-feature-enabled-by-namespace-ids' => '',
          'x-gitlab-base-url' => 'http://localhost',
          'x-gitlab-global-user-id' => Gitlab::GlobalAnonymousId.user_id(user),
          'x-gitlab-user-id' => user.id.to_s,
          'x-gitlab-host-name' => 'localhost',
          'x-gitlab-instance-id' => 'uuid-not-set',
          'x-gitlab-realm' => 'self-managed',
          'x-gitlab-version' => Gitlab.version_info.to_s,
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'true',
          'x-gitlab-enabled-feature-flags' => '',
          'x-gitlab-feature-enablement-type' => ''
        }

        expect(described_class.cloud_connector_headers(user: user)).to eq(expected_headers)
      end
    end
  end

  describe '.cloud_connector_token' do
    let_it_be(:group) { create(:group, maintainers: user) }

    let(:token) { 'duo_workflow_token_456' }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(::CloudConnector::Tokens).to receive(:get).and_return(token)
    end

    it 'gets token with correct parameters' do
      expect(::CloudConnector::Tokens).to receive(:get).with(
        unit_primitive: :duo_agent_platform,
        resource: user
      )

      expect(described_class.cloud_connector_token(user: user)).to eq(token)
    end
  end

  describe '.self_hosted_url' do
    subject(:self_hosted_url) { described_class.self_hosted_url }

    context 'when AI setting has duo_agent_platform_service_url configured' do
      let(:service_url) { 'self-hosted-dap-service-url:50052' }

      before do
        ::Ai::Setting.instance.update!(duo_agent_platform_service_url: service_url)
      end

      it 'returns the configured service URL' do
        expect(self_hosted_url).to eq(service_url)
      end
    end

    context 'when AI setting has empty duo_agent_platform_service_url' do
      before do
        ::Ai::Setting.instance.update!(duo_agent_platform_service_url: '')
      end

      it 'returns nil' do
        expect(self_hosted_url).to be_nil
      end
    end
  end

  describe '.metadata' do
    it 'returns workflow related user metadata' do
      expect(described_class.metadata(user)).to eq({ extended_logging: true, is_team_member: nil })
    end

    context 'for extended logging' do
      context 'when `duo_workflow_extended_logging` feature flag is enabled' do
        it 'returns true' do
          expect(described_class.metadata(user)[:extended_logging]).to eq(true)
        end
      end

      context 'when `duo_workflow_extended_logging` feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_extended_logging: false)
        end

        it 'returns false' do
          expect(described_class.metadata(user)[:extended_logging]).to eq(false)
        end
      end
    end

    context 'on a self-hosted Duo instance' do
      before do
        ::Ai::Setting.instance.update!(duo_agent_platform_service_url: 'localhost:50052')
      end

      context 'when enabled_instance_verbose_ai_logs setting is enabled' do
        before do
          ::Ai::Setting.instance.update!(enabled_instance_verbose_ai_logs: true)
        end

        it 'returns true' do
          expect(described_class.metadata(user)[:extended_logging]).to eq(true)
        end
      end

      context 'when enabled_instance_verbose_ai_logs setting is disabled' do
        before do
          ::Ai::Setting.instance.update!(enabled_instance_verbose_ai_logs: false)
        end

        it 'returns false' do
          expect(described_class.metadata(user)[:extended_logging]).to eq(false)
        end
      end
    end
  end
end
