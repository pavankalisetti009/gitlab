# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::Registry, feature_category: :duo_setting do
  let(:user) { build(:user) }
  let(:default_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe)
    ]
  end

  let(:development_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
    ]
  end

  let(:amazon_q_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe)
    ]
  end

  let(:self_hosted_only_probe_types) do
    [
      an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe)
    ]
  end

  subject(:registry) { described_class.new(user) }

  describe '#default_probes' do
    it 'returns the correct number and types of default probes' do
      probes = registry.default_probes

      expect(probes).to match(default_probe_types)
    end
  end

  describe '#development_probes' do
    it 'returns the correct number and types of development probes' do
      probes = registry.development_probes

      expect(probes).to match(development_probe_types)
    end
  end

  describe '#amazon_q_probes' do
    it 'returns the correct number and types of Amazon Q probes' do
      probes = registry.amazon_q_probes

      expect(probes).to match(amazon_q_probe_types)
    end
  end

  describe '#self_hosted_probes' do
    context 'for self-hosted probes' do
      context 'when at least one vendored feature exists' do
        before do
          create(:ai_feature_setting, provider: :vendored)
        end

        context 'when code completions is vendored' do
          before do
            create(:ai_feature_setting, feature: :code_completions, provider: :vendored)
          end

          it 'returns self-hosted probes combined with default probes including EndToEndProbe' do
            probes = registry.self_hosted_probes

            expect(probes).to match(default_probe_types + self_hosted_only_probe_types)
          end
        end

        context 'when code completions is not vendored' do
          before do
            create(:ai_feature_setting, feature: :code_completions, provider: :self_hosted)
          end

          it 'returns self-hosted probes combined with default probes excluding EndToEndProbe' do
            probes = registry.self_hosted_probes

            expect(probes).not_to include(an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe))
          end
        end
      end

      context 'when no vendored features exist' do
        it 'returns only self-hosted specific probes' do
          probes = registry.self_hosted_probes

          expect(probes.size).to eq(3)
          expect(probes).to match(self_hosted_only_probe_types)
        end

        it 'excludes Duo Agent Platform probe' do
          probes = registry.self_hosted_probes
          expect(probes).not_to include(an_instance_of(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe))
        end
      end
    end

    context 'when Duo Agent Platform URL is set up' do
      before do
        Ai::Setting.instance.update!(duo_agent_platform_service_url: 'localhost:50052')
      end

      it 'returns self-hosted probes with Duo Agent Platform probe' do
        probes = registry.self_hosted_probes

        expect(probes).to match(
          self_hosted_only_probe_types +
          [an_instance_of(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe)]
        )
      end
    end
  end
end
