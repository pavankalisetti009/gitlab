# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoCodeReview::Modes::Dap, feature_category: :code_suggestions do
  subject(:mode) { described_class.new(user: user, container: container) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
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

    # Application settings
    let(:duo_features_enabled) { true }
    let(:duo_foundational_flows_enabled) { true }
    let(:duo_code_review_dap_available) { true }

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
        duo_foundational_flows_enabled: duo_foundational_flows_enabled,
        duo_code_review_dap_available?: duo_code_review_dap_available
      )

      allow(user).to receive(:allowed_to_use?)
        .with(:duo_agent_platform, root_namespace: container.root_ancestor)
        .and_return(user_allowed_to_use_duo_agent_platform)

      allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: nil)
        )
      end
    end

    shared_examples 'not active' do
      it 'is not active' do
        expect(mode).not_to be_active
      end
    end

    shared_examples 'active' do
      it 'is active' do
        expect(mode).to be_active
      end
    end

    context 'when no user in the context' do
      let(:user) { nil }

      include_examples 'not active'
    end

    context 'when Duo features are disabled' do
      let(:duo_features_enabled) { false }

      include_examples 'not active'
    end

    context 'when user has duo_enterprise add-on' do
      context 'on SaaS' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: group)
        end

        let_it_be(:user_add_on_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
        end

        before do
          stub_saas_features(gitlab_duo_saas_only: true)
        end

        context 'and duo_code_review_dap_internal_users feature flag is enabled' do
          include_examples 'active'
        end

        context 'and duo_code_review_dap_internal_users feature flag is disabled' do
          let(:duo_code_review_dap_internal_users) { false }

          include_examples 'not active'
        end

        context 'when user does not have a seat assignment' do
          let(:user_allowed_to_use_duo_agent_platform) { false }

          before do
            user_add_on_assignment.destroy!
          end

          include_examples 'not active'
        end
      end

      context 'on self-managed' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :active, :self_managed, add_on: add_on)
        end

        let_it_be(:user_add_on_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
        end

        before do
          stub_saas_features(gitlab_duo_saas_only: false)
        end

        context 'and duo_code_review_dap_internal_users feature flag is enabled' do
          include_examples 'active'
        end

        context 'and duo_code_review_dap_internal_users feature flag is disabled' do
          let(:duo_code_review_dap_internal_users) { false }

          include_examples 'not active'
        end

        context 'when user does not have a seat assignment' do
          let(:user_allowed_to_use_duo_agent_platform) { false }

          before do
            user_add_on_assignment.destroy!
          end

          include_examples 'not active'
        end
      end
    end

    context 'when user is not allowed to use Duo Agent Platform' do
      let(:user_allowed_to_use_duo_agent_platform) { false }

      include_examples 'not active'
    end

    context 'when DAP Duo Code Review is disabled for the container' do
      let(:duo_code_review_dap_available) { false }

      include_examples 'not active'
    end

    context 'when SaaS mode or self-managed using cloud-connected models' do
      before do
        allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: nil)
          )
        end
      end

      include_examples 'active'
    end

    context 'when self-managed using self-hosted models' do
      context 'with an incompatible model' do
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

      context 'without a self-hosted model' do
        let(:feature_setting) do
          instance_double(
            ::Ai::FeatureSetting,
            self_hosted?: true,
            self_hosted_model: nil
          )
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: feature_setting)
            )
          end
          allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
        end

        include_examples 'not active'
      end

      context 'with a self-hosted model' do
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
    end
  end
end
