# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoCodeReview::Modes::Dap, feature_category: :code_suggestions do
  subject(:mode) { described_class.new(user: user, container: container) }

  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:container) { project }

  describe '#mode' do
    it 'returns the mode name' do
      expect(mode.mode).to eq(:dap)
    end
  end

  describe '#enabled?' do
    it 'always returns true' do
      expect(mode).to be_enabled
    end
  end

  describe '#active?' do
    # Feature flags
    let(:duo_code_review_dap_internal_users) { true }

    # Duo features
    let(:dap_enabled) { true }
    let(:duo_features_enabled) { true }
    let(:experiment_features_enabled) { true }

    # User permissions
    let(:user_allowed_to_use_duo_agent_platform) { true }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(container, :duo_workflow)
        .and_return(dap_enabled)

      stub_feature_flags(
        duo_code_review_dap_internal_users: duo_code_review_dap_internal_users
      )

      allow(container).to receive_messages(
        duo_features_enabled: duo_features_enabled,
        experiment_features_enabled: experiment_features_enabled
      )

      allow(user).to receive(:allowed_to_use?)
        .with(:duo_agent_platform)
        .and_return(user_allowed_to_use_duo_agent_platform)

      allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: nil)
        )
      end
    end

    shared_examples 'not active' do
      it 'returns false' do
        expect(mode).not_to be_active
      end
    end

    shared_examples 'active' do
      it 'returns true' do
        expect(mode).to be_active
      end
    end

    context 'when Duo features are disabled' do
      let(:duo_features_enabled) { false }

      include_examples 'not active'
    end

    context 'when user is not allowed to use duo_agent_platform' do
      let(:user_allowed_to_use_duo_agent_platform) { false }

      include_examples 'not active'
    end

    context 'when DUO Agent Platform is not available' do
      let(:dap_enabled) { false }

      include_examples 'not active'
    end

    context 'when duo_agent_platform is not configured' do
      before do
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: nil)
          )
        end
      end

      context 'and SaaS feature is available' do
        include_examples 'active'
      end

      context 'and SaaS feature is not available' do
        before do
          allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        end

        include_examples 'active'
      end
    end

    context 'when self-hosted model is unsupported for duo agent platform code review' do
      let(:self_hosted_model) { instance_double(::Ai::SelfHostedModel) }
      let(:feature_setting) do
        instance_double(
          ::Ai::FeatureSetting,
          self_hosted?: true,
          self_hosted_model: self_hosted_model
        )
      end

      before do
        allow(self_hosted_model).to receive(:unsupported_family_for_duo_agent_platform_code_review?).and_return(true)
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: feature_setting)
          )
        end
      end

      include_examples 'not active'
    end

    context 'when self-hosted model is supported but DWS URL is not configured' do
      let(:self_hosted_model) { instance_double(::Ai::SelfHostedModel) }
      let(:feature_setting) do
        instance_double(
          ::Ai::FeatureSetting,
          self_hosted?: true,
          self_hosted_model: self_hosted_model
        )
      end

      before do
        allow(self_hosted_model).to receive(:unsupported_family_for_duo_agent_platform_code_review?).and_return(false)
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: feature_setting)
          )
        end
        allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
      end

      include_examples 'not active'
    end

    context 'when self-hosted model is supported and DWS URL is configured' do
      let(:self_hosted_model) { instance_double(::Ai::SelfHostedModel) }
      let(:feature_setting) do
        instance_double(
          ::Ai::FeatureSetting,
          self_hosted?: true,
          self_hosted_model: self_hosted_model
        )
      end

      before do
        allow(self_hosted_model).to receive(:unsupported_family_for_duo_agent_platform_code_review?).and_return(false)
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: feature_setting)
          )
        end
        allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('https://dws.example.com')
      end

      include_examples 'active'
    end

    context 'when feature setting service returns failure' do
      before do
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Service error')
          )
        end
      end

      include_examples 'active'
    end
  end
end
