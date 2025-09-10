# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService, feature_category: :agent_foundations do
  let_it_be(:group) { create(:group) }

  subject(:service) { described_class.new(root_namespace: root_namespace) }

  shared_examples 'returns empty headers' do
    it 'returns empty hash' do
      result = service.execute
      expect(result).to eq({})
    end
  end

  describe '#execute' do
    context 'for self-hosted Duo instances' do
      let(:root_namespace) { nil }

      context 'when self_hosted_agent_platform feature flag is enabled' do
        before do
          stub_feature_flags(self_hosted_agent_platform: true)
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(duo_agent_platform_model_selection: false)
        end

        context 'with self-hosted feature setting' do
          let_it_be(:feature_setting) do
            create(:ai_feature_setting,
              feature: :duo_agent_platform,
              provider: :self_hosted,
              self_hosted_model: create(:ai_self_hosted_model, model: :claude_3))
          end

          it 'returns model metadata headers from existing ModelMetadata class' do
            result = service.execute

            expect(result).to have_key('x-gitlab-agent-platform-model-metadata')

            metadata_json = result['x-gitlab-agent-platform-model-metadata']
            metadata = ::Gitlab::Json.parse(metadata_json)
            expect(metadata).to include(
              'provider' => feature_setting.self_hosted_model.provider.to_s,
              'name' => feature_setting.self_hosted_model.model
            )
          end
        end

        context 'when feature setting is not ready (disabled provider)' do
          before do
            create(:ai_feature_setting,
              feature: :duo_agent_platform,
              provider: :disabled,
              self_hosted_model: nil)
          end

          it_behaves_like 'returns empty headers'
        end
      end
    end

    context 'for cloud-connected self-managed instances' do
      let(:root_namespace) { nil }

      context 'when instance_level_model_selection feature flag is enabled' do
        before do
          stub_feature_flags(instance_level_model_selection: true)
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(self_hosted_agent_platform: false)
        end

        context 'with instance model selection setting (priority 1)' do
          let!(:instance_setting) do
            create(:instance_model_selection_feature_setting,
              feature: :duo_agent_platform,
              offered_model_ref: 'claude-3-7-sonnet-20250219'
            )
          end

          it 'returns model metadata headers for cloud-connected' do
            result = service.execute

            expect(result).to eq(
              'x-gitlab-agent-platform-model-metadata' => {
                'provider' => 'gitlab',
                'feature_setting' => 'duo_agent_platform',
                'identifier' => 'claude-3-7-sonnet-20250219'
              }.to_json
            )
          end
        end

        context 'when instance setting has no model ref' do
          let!(:instance_setting) do
            create(:instance_model_selection_feature_setting,
              feature: :duo_agent_platform,
              offered_model_ref: nil
            )
          end

          it 'returns model metadata headers for cloud-connected wit gitlab default model' do
            result = service.execute

            expect(result).to eq(
              'x-gitlab-agent-platform-model-metadata' => {
                'provider' => 'gitlab',
                'feature_setting' => 'duo_agent_platform',
                'identifier' => nil
              }.to_json
            )
          end
        end
      end

      context 'when instance_level_model_selection feature flag is disabled' do
        before do
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(self_hosted_agent_platform: false)
        end

        it 'returns empty headers' do
          result = service.execute

          expect(result).to eq({})
        end
      end
    end

    context 'for GitLab.com instances', :saas do
      let(:root_namespace) { group }

      context 'when duo_agent_platform_model_selection feature flag is enabled' do
        before do
          stub_feature_flags(duo_agent_platform_model_selection: group)
          stub_feature_flags(ai_model_switching: group)
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(self_hosted_agent_platform: false)
        end

        context 'with namespace-level model selection (priority 1)' do
          before do
            create(:ai_namespace_feature_setting,
              namespace: group,
              feature: :duo_agent_platform,
              offered_model_ref: 'claude-3-7-sonnet-20250219')
          end

          it 'uses namespace-level model selection' do
            result = service.execute

            expect(result).to include(
              'x-gitlab-agent-platform-model-metadata' => {
                'provider' => 'gitlab',
                'feature_setting' => 'duo_agent_platform',
                'identifier' => 'claude-3-7-sonnet-20250219'
              }.to_json
            )
          end
        end

        context 'when ai_model_switching is disabled' do
          before do
            stub_feature_flags(ai_model_switching: false)
            stub_feature_flags(duo_agent_platform_model_selection: false)
            stub_feature_flags(self_hosted_agent_platform: false)
          end

          it_behaves_like 'returns empty headers'
        end

        context 'without root_namespace provided' do
          let(:root_namespace) { nil }

          it_behaves_like 'returns empty headers'
        end
      end

      context 'when duo_agent_platform_model_selection feature flag is disabled' do
        before do
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(ai_model_switching: false)
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(self_hosted_agent_platform: false)
        end

        it_behaves_like 'returns empty headers'
      end
    end
  end
end
