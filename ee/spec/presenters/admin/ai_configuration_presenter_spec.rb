# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::AiConfigurationPresenter, feature_category: :ai_abstraction_layer do
  let_it_be(:default_organization) { build(:organization) }

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  describe '#settings' do
    subject(:settings) { described_class.new(current_user).settings }

    let(:current_user) { build(:admin) }
    let(:application_setting_attributes) do
      {
        disabled_direct_code_suggestions?: true,
        duo_availability: 'default_off',
        duo_remote_flows_availability: true,
        duo_foundational_flows_availability: false,
        duo_workflows_default_image_registry: nil,
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        enabled_expanded_logging: true,
        gitlab_dedicated_instance?: false,
        instance_level_ai_beta_features_enabled: true,
        model_prompt_cache_enabled?: true
      }
    end

    let(:ai_settings) do
      Ai::Setting.instance.tap do |settings|
        allow(settings).to receive_messages(
          ai_gateway_url: 'http://localhost:3000',
          duo_agent_platform_service_url: 'localhost:50052',
          ai_gateway_timeout_seconds: 60,
          duo_core_features_enabled?: true,
          duo_agent_platform_enabled: true,
          foundational_agents_default_enabled: true
        )
      end
    end

    let(:beta_self_hosted_models_enabled) { true }
    let(:active_duo_add_ons_exist?) { true }
    let(:namespace_access_rules) do
      {
        1 => [
          instance_double(
            ::Ai::FeatureAccessRule,
            through_namespace: instance_double(
              Namespace,
              id: 1,
              name: 'Group A',
              full_path: 'group-a'
            ),
            accessible_entity: 'duo_classic'
          )
        ],
        2 => [
          instance_double(
            ::Ai::FeatureAccessRule,
            through_namespace: instance_double(
              Namespace,
              id: 2,
              name: 'Group B',
              full_path: 'group-b'
            ),
            accessible_entity: 'duo_agent_platform'
          )
        ]
      }
    end

    let(:transformed_namespace_access_rules) do
      [
        {
          through_namespace: {
            id: 1,
            name: 'Group A',
            full_path: 'group-a'
          },
          features: ["duo_classic"]
        }, {
          through_namespace: {
            id: 2,
            name: 'Group B',
            full_path: 'group-b'
          },
          features: ['duo_agent_platform']
        }
      ]
    end

    before do
      stub_ee_application_setting(**application_setting_attributes)

      allow(GitlabSubscriptions::AddOnPurchase)
        .to receive(:active_duo_add_ons_exist?)
        .with(:instance)
        .and_return(active_duo_add_ons_exist?)

      allow(Ai::Setting).to receive(:instance).and_return(ai_settings)

      allow(Ai::TestingTermsAcceptance)
        .to receive(:has_accepted?)
        .and_return(beta_self_hosted_models_enabled)

      allow(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :update_dap_self_hosted_model).and_return(true)

      allow(Ai::FeatureAccessRule).to receive(:duo_root_namespace_access_rules).and_return namespace_access_rules

      stub_licensed_features(ai_features: true)

      stub_feature_flags(duo_foundational_agents_per_agent_availability: false)
    end

    specify do
      expect(settings).to include(
        ai_gateway_url: 'http://localhost:3000',
        ai_gateway_timeout_seconds: '60',
        duo_agent_platform_service_url: 'localhost:50052',
        duo_agent_platform_enabled: 'true',
        expose_duo_agent_platform_service_url: 'true',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        beta_self_hosted_models_enabled: 'true',
        can_manage_self_hosted_models: 'true',
        can_configure_ai_logging: 'true',
        disabled_direct_connection_method: 'true',
        duo_availability: 'default_off',
        duo_remote_flows_availability: 'true',
        duo_foundational_flows_availability: 'false',
        duo_workflows_default_image_registry: '',
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        duo_core_features_enabled: 'true',
        duo_pro_visible: 'true',
        enabled_expanded_logging: 'true',
        experiment_features_enabled: 'true',
        on_general_settings_page: 'false',
        prompt_cache_enabled: 'true',
        redirect_path: '/admin/gitlab_duo',
        toggle_beta_models_path: '/admin/ai/duo_self_hosted/toggle_beta_models',
        foundational_agents_default_enabled: 'true',
        show_foundational_agents_availability: 'true',
        show_foundational_agents_per_agent_availability: 'false',
        show_duo_agent_platform_enablement_setting: 'true',
        namespace_access_rules: Gitlab::Json.dump(transformed_namespace_access_rules),
        ai_minimum_access_level_to_execute: '',
        ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER.to_s
      )
    end

    context 'with duo_foundational_agents_per_agent_availability flag enabled' do
      before do
        stub_feature_flags(duo_foundational_agents_per_agent_availability: true)
      end

      it { expect(settings).to include(show_foundational_agents_per_agent_availability: 'true') }
    end

    context 'with duo_access_through_namespaces feature flag disabled' do
      before do
        stub_feature_flags(duo_access_through_namespaces: false)
      end

      it { expect(settings).not_to have_key(:namespace_access_rules) }
    end

    context 'with foundational_agents_default_enabled false' do
      before do
        allow(ai_settings).to receive_messages(foundational_agents_default_enabled: false)
      end

      it { expect(settings).to include(foundational_agents_default_enabled: 'false') }
    end

    context 'with another ai_gateway_url' do
      before do
        allow(ai_settings).to receive_messages(ai_gateway_url: 'https://example.com')
      end

      it { expect(settings).to include(ai_gateway_url: 'https://example.com') }
    end

    context 'without active Duo add-on' do
      let(:active_duo_add_ons_exist?) { false }

      it { expect(settings).to include(are_experiment_settings_allowed: 'false') }
      it { expect(settings).to include(duo_pro_visible: 'false') }
    end

    context 'with beta self-hosted models enabled' do
      let(:beta_self_hosted_models_enabled) { 'false' }

      it { expect(settings).to include(beta_self_hosted_models_enabled: 'false') }
    end

    context 'when user cannot manage self-hosted models' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings).and_return(false)
      end

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'when user cannot update DAP self-hosted models' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :update_dap_self_hosted_model).and_return(false)
      end

      it { expect(settings).to include(expose_duo_agent_platform_service_url: 'false') }
    end

    context 'with enabled direct code suggestions' do
      let(:application_setting_attributes) { super().merge(disabled_direct_code_suggestions?: false) }

      it { expect(settings).to include(disabled_direct_connection_method: 'false') }
    end

    context 'with other Duo availability' do
      let(:application_setting_attributes) { super().merge(duo_availability: 'always_off') }

      it { expect(settings).to include(duo_availability: 'always_off') }
    end

    context 'with other Duo chat expiration column' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_column: 'last_created_at') }

      it { expect(settings).to include(duo_chat_expiration_column: 'last_created_at') }
    end

    context 'with other Duo chat expiration days' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_days: '10') }

      it { expect(settings).to include(duo_chat_expiration_days: '10') }
    end

    context 'without Duo Core features disabled' do
      before do
        allow(ai_settings).to receive_messages(duo_core_features_enabled?: false)
      end

      it { expect(settings).to include(duo_core_features_enabled: 'false') }
    end

    context 'when on SaaS' do
      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      end

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
    end

    context 'when on GitLab Dedicated' do
      let(:application_setting_attributes) { super().merge(gitlab_dedicated_instance?: true) }

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
    end

    context 'when AI features are not available' do
      before do
        allow(License).to receive(:ai_features_available?).and_return(false)
      end

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
    end

    context 'without expanded logging' do
      let(:application_setting_attributes) { super().merge(enabled_expanded_logging: false) }

      it { expect(settings).to include(enabled_expanded_logging: 'false') }
    end

    context 'without experiment features enabled' do
      let(:application_setting_attributes) { super().merge(instance_level_ai_beta_features_enabled: false) }

      it { expect(settings).to include(experiment_features_enabled: 'false') }
    end

    context 'without prompt cache' do
      let(:application_setting_attributes) { super().merge(model_prompt_cache_enabled?: false) }

      it { expect(settings).to include(prompt_cache_enabled: 'false') }
    end

    context 'with different AI minimum access levels' do
      before do
        allow(ai_settings).to receive_messages(
          ai_minimum_access_level_execute_with_fallback: Gitlab::Access::MAINTAINER,
          ai_minimum_access_level_execute_async_with_fallback: Gitlab::Access::OWNER
        )
      end

      it { expect(settings).to include(ai_minimum_access_level_to_execute: Gitlab::Access::MAINTAINER.to_s) }
      it { expect(settings).to include(ai_minimum_access_level_to_execute_async: Gitlab::Access::OWNER.to_s) }
    end

    context 'with duo_workflows_default_image_registry set' do
      let(:application_setting_attributes) do
        super().merge(duo_workflows_default_image_registry: 'registry.example.com')
      end

      it { expect(settings).to include(duo_workflows_default_image_registry: 'registry.example.com') }
    end

    describe 'foundational_agent_statuses' do
      include_context 'with mocked Foundational Chat Agents'

      it 'returns all foundational agents except duo chat with default enabled status' do
        statuses = Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses))

        expect(statuses).to match_array([
          { "description" => "First agent", "enabled" => nil, "name" => "Agent 1", "reference" => "agent_1" },
          { "description" => "Second agent", "enabled" => nil, "name" => "Agent 2", "reference" => "agent_2" }
        ])
      end
    end
  end
end
