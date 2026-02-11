# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Groups::SettingsHelper, feature_category: :groups_and_projects do
  include_context 'with mocked Foundational Chat Agents'

  let(:namespace_settings) do
    build(:namespace_settings, unique_project_download_limit: 1,
      unique_project_download_limit_interval_in_seconds: 2,
      unique_project_download_limit_allowlist: %w[username1 username2],
      unique_project_download_limit_alertlist: [3, 4],
      auto_ban_user_on_excessive_projects_download: true)
  end

  let(:ai_settings) do
    build(:namespace_ai_settings, duo_workflow_mcp_enabled: true)
  end

  let(:foundational_agents_status_records) do
    [build(:namespace_foundational_agent_statuses, reference: foundational_chat_agent_1_ref)]
  end

  let(:group) do
    build(
      :group,
      namespace_settings: namespace_settings,
      ai_settings: ai_settings, id: 7,
      foundational_agents_status_records: foundational_agents_status_records
    )
  end

  let(:subgroup1) { build_stubbed(:group, parent: group) }
  let(:subgroup2) { build_stubbed(:group, parent: group) }

  let(:current_user) { build(:user) }

  before do
    helper.instance_variable_set(:@group, group)
    allow(helper).to receive(:current_user).and_return(current_user)
    allow(helper).to receive(:instance_variable_get).with(:@current_user).and_return(current_user)
    allow(::GitlabSubscriptions::AddOnPurchase)
      .to receive_message_chain(:for_self_managed, :for_duo_pro_or_duo_enterprise, :active, :first)
  end

  describe '.unique_project_download_limit_settings_data', feature_category: :insider_threat do
    subject { helper.unique_project_download_limit_settings_data }

    it 'returns the expected data' do
      is_expected.to eq({ group_full_path: group.full_path,
                          max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#group_ai_general_settings_helper_data' do
    subject(:group_ai_general_settings_helper_data) { helper.group_ai_general_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_general_settings_helper_data).to include(
        on_general_settings_page: 'true',
        redirect_path: edit_group_path(group),
        base_data: 'data'
      )
    end
  end

  describe '#group_ai_configuration_settings_helper_data' do
    subject(:group_ai_configuration_settings_helper_data) { helper.group_ai_configuration_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_configuration_settings_helper_data).to include(
        on_general_settings_page: 'false',
        redirect_path: group_settings_gitlab_duo_path(group),
        base_data: 'data'
      )
    end
  end

  describe 'group_ai_settings_helper_data' do
    subject(:settings) { helper.group_ai_settings_helper_data }

    let(:add_on_purchase) { nil }
    let(:root_ancestor) { group }
    let(:test_workflows) do
      [
        {
          foundational_flow_reference: 'test_flow/v1',
          display_name: 'Test Flow',
          description: 'Test Description',
          feature_maturity: 'ga'
        },
        {
          foundational_flow_reference: 'beta_flow/v1',
          display_name: 'Beta Flow',
          description: 'Beta Flow Description',
          feature_maturity: 'beta'
        }
      ]
    end

    let(:subgroup1) { build_stubbed(:group, parent: group) }
    let(:subgroup2) { build_stubbed(:group, parent: group) }

    let(:namespace_access_rules_mock) do
      {
        subgroup1.id => [
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup1,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          ),
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup1,
            root_namespace: group,
            accessible_entity: 'duo_agent_platform'
          )
        ],
        subgroup2.id => [
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup2,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          )
        ]
      }
    end

    let(:namespace_access_rules_result) do
      [
        {
          through_namespace: {
            id: subgroup1.id,
            name: subgroup1.name,
            full_path: subgroup1.full_path
          },
          features: %w[duo_classic duo_agent_platform]
        }, {
          through_namespace: {
            id: subgroup2.id,
            name: subgroup2.name,
            full_path: subgroup2.full_path
          },
          features: %w[duo_classic]
        }
      ]
    end

    before do
      allow(current_user).to receive(:can?).with(:admin_duo_workflow, group).and_return(true)
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_const('::Ai::Catalog::FoundationalFlow::ITEMS', test_workflows)

      allow(Ai::NamespaceFeatureAccessRule).to receive(:by_root_namespace_group_by_through_namespace)
        .and_return namespace_access_rules_mock
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          duo_availability_cascading_settings: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_availability: group.namespace_settings.duo_availability.to_s,
          duo_remote_flows_cascading_settings: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_remote_flows_availability: group.namespace_settings.duo_remote_flows_availability.to_s,
          duo_foundational_flows_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_foundational_flows_availability: group.namespace_settings.duo_foundational_flows_availability.to_s,
          duo_core_features_enabled: group.namespace_settings.duo_core_features_enabled.to_s,
          prompt_injection_protection_available: "true",
          prompt_injection_protection_level: "log_only",
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?.to_s,
          experiment_features_enabled: group.namespace_settings.experiment_features_enabled.to_s,
          prompt_cache_enabled: group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          update_id: group.id,
          duo_workflow_available: "true",
          duo_agent_platform_enabled: "true",
          duo_workflow_mcp_enabled: "true",
          ai_usage_data_collection_available: "true",
          ai_usage_data_collection_enabled: "false",
          foundational_agents_default_enabled: "true",
          foundational_agents_statuses: Gitlab::Json.generate([
            { reference: 'agent_1', name: 'Agent 1', description: 'First agent', enabled: true },
            { reference: 'agent_2', name: 'Agent 2', description: 'Second agent', enabled: nil }
          ]),
          show_foundational_agents_availability: "true",
          show_foundational_agents_per_agent_availability: "true",
          show_duo_agent_platform_enablement_setting: "true",
          is_saas: 'true',
          ai_minimum_access_level_to_execute: nil,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER,
          ai_settings_minimum_access_level_manage: nil,
          ai_settings_minimum_access_level_enable_on_projects: nil,
          available_foundational_flows: Gitlab::Json.generate([{
            name: 'Test Flow',
            description: 'Test Description',
            reference: 'test_flow/v1'
          }]),
          selected_foundational_flow_references: '[]',
          namespace_access_rules: Gitlab::Json.dump(namespace_access_rules_result),
          parent_path: group.full_path
        }
      )
    end

    context 'when SaaS group has enabled experimental/beta AI features' do
      before do
        namespace_settings.experiment_features_enabled = true
      end

      it 'also contains beta/experimental foundational flow data' do
        expect(settings[:available_foundational_flows]).to eq(
          Gitlab::Json.generate([
            { name: 'Test Flow', description: 'Test Description', reference: 'test_flow/v1' },
            { name: 'Beta Flow', description: 'Beta Flow Description', reference: 'beta_flow/v1' }
          ])
        )
      end
    end

    context 'when not SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'only contains GA foundational flow data' do
        expect(settings[:available_foundational_flows]).to eq(
          Gitlab::Json.generate([
            { name: 'Test Flow', description: 'Test Description', reference: 'test_flow/v1' }
          ])
        )
      end

      context 'when instance has enabled experimental/beta AI features' do
        before do
          stub_application_setting(instance_level_ai_beta_features_enabled: true)
        end

        it 'also contains beta/experimental foundational flow data' do
          expect(settings[:available_foundational_flows]).to eq(
            Gitlab::Json.generate([
              { name: 'Test Flow', description: 'Test Description', reference: 'test_flow/v1' },
              { name: 'Beta Flow', description: 'Beta Flow Description', reference: 'beta_flow/v1' }
            ])
          )
        end
      end
    end

    context 'with duo_access_through_namespaces disabled' do
      before do
        stub_feature_flags(duo_access_through_namespaces: false)
      end

      it { expect(settings).not_to have_key(:parent_path) }
      it { expect(settings).not_to have_key(:namespace_access_rules) }
    end

    context 'without an ai_settings record' do
      let(:group) { build(:group, namespace_settings: namespace_settings, id: 7) }

      it 'returns the expected data' do
        is_expected.to include(
          is_saas: 'true',
          duo_workflow_mcp_enabled: 'false',
          ai_usage_data_collection_available: 'true',
          ai_usage_data_collection_enabled: 'false',
          foundational_agents_default_enabled: 'true',
          duo_agent_platform_enabled: 'true',
          ai_minimum_access_level_to_execute: nil,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER,
          ai_settings_minimum_access_level_manage: nil,
          ai_settings_minimum_access_level_enable_on_projects: nil
        )
      end
    end

    context 'when ai_settings minimum access levels have been set' do
      let(:ai_settings) do
        build(:namespace_ai_settings,
          minimum_access_level_execute: ::Gitlab::Access::DEVELOPER,
          minimum_access_level_execute_async: ::Gitlab::Access::GUEST,
          minimum_access_level_manage: ::Gitlab::Access::MAINTAINER,
          minimum_access_level_enable_on_projects: ::Gitlab::Access::OWNER)
      end

      it 'returns the expected data' do
        is_expected.to include(
          ai_minimum_access_level_to_execute: Gitlab::Access::DEVELOPER,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::GUEST,
          ai_settings_minimum_access_level_manage: Gitlab::Access::MAINTAINER,
          ai_settings_minimum_access_level_enable_on_projects: Gitlab::Access::OWNER
        )
      end
    end

    context 'with a group that is not a root namespace' do
      before do
        allow(group).to receive(:root?).and_return(false)
        group.ai_settings = build(:namespace_ai_settings, duo_workflow_mcp_enabled: false)
      end

      it 'returns the expected data' do
        is_expected.to include(
          {
            duo_workflow_available: "false",
            duo_workflow_mcp_enabled: "false",
            ai_usage_data_collection_available: "false",
            available_foundational_flows: '[]',
            selected_foundational_flow_references: '[]'
          }
        )
      end
    end

    describe 'show_foundational_agents_availability' do
      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_availability: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_availability: "false" })
        end
      end
    end

    describe "show_foudnational-agents_per_agent_availability" do
      context 'with duo_foundational_agents_per_agent_availability feature flag is disabled' do
        before do
          stub_feature_flags(duo_foundational_agents_per_agent_availability: false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_per_agent_availability: "false" })
        end
      end

      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_per_agent_availability: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_per_agent_availability: "false" })
        end
      end
    end

    describe 'show_duo_agent_platform_enablement_setting' do
      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_duo_agent_platform_enablement_setting: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_duo_agent_platform_enablement_setting: "false" })
        end
      end
    end

    context 'with GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'return is_saas as true' do
        is_expected.to include(is_saas: 'false')
      end
    end
  end

  describe 'group_amazon_q_settings_view_model_data' do
    subject(:group_amazon_q_settings_view_model_data) { helper.group_amazon_q_settings_view_model_data }

    before do
      group.amazon_q_integration = build(:amazon_q_integration, instance: false, auto_review_enabled: true)
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          group_id: group.id.to_s,
          init_availability: group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: true,
          duo_availability_cascading_settings: { locked_by_application_setting: false, locked_by_ancestor: false },
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?
        }
      )
    end
  end

  describe 'group_amazon_q_settings_view_model_json' do
    subject(:group_amazon_q_settings_view_model_json) { helper.group_amazon_q_settings_view_model_json }

    it 'returns the expected data' do
      is_expected.to eq(
        {
          groupId: "7",
          initAvailability: "default_on",
          initAutoReviewEnabled: false,
          areDuoSettingsLocked: false,
          duoAvailabilityCascadingSettings: { lockedByApplicationSetting: false, lockedByAncestor: false }
        }.to_json
      )
    end
  end

  describe 'show_group_ai_settings_general?' do
    let(:duo_settings_available?) { true }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
    let(:root_ancestor) { create(:group) }
    let(:group) { create(:group, parent: root_ancestor) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    before do
      allow(GitlabSubscriptions::Duo)
        .to receive(:duo_settings_available?)
        .with(root_ancestor)
        .and_return(duo_settings_available?)
    end

    it { expect(helper).to be_show_group_ai_settings_general }

    context 'when group has no trial or add-on' do
      let(:duo_settings_available?) { false }

      it { expect(helper).not_to be_show_group_ai_settings_general }
    end
  end

  describe 'show_group_ai_settings_page?' do
    using RSpec::Parameterized::TableSyntax
    subject { helper.show_group_ai_settings_page? }

    where(:licensed_ai_features_available, :show_gitlab_duo_settings_app, :expected_result) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        allow(group).to receive(:licensed_ai_features_available?).and_return(licensed_ai_features_available)
        allow(helper).to receive(:show_gitlab_duo_settings_app?).with(group).and_return(show_gitlab_duo_settings_app)
      end

      it 'returns the expected result' do
        expect(helper.show_group_ai_settings_page?).to eq(expected_result)
      end
    end
  end

  describe '#show_virtual_registries_setting?' do
    using RSpec::Parameterized::TableSyntax

    let(:policy_subject) { instance_double(::VirtualRegistries::Policies::Group) }

    where(:maven_virtual_registry, :licensed_feature, :can_admin, :expected_result) do
      true  | true  | true  | true
      false | true  | true  | false
      true  | false | true  | false
      true  | true  | false | false
      false | false | false | false
    end

    with_them do
      before do
        stub_feature_flags(maven_virtual_registry: maven_virtual_registry)
        stub_licensed_features(packages_virtual_registry: licensed_feature)
        allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
        allow(Ability).to receive(:allowed?).with(current_user, :admin_virtual_registry,
          policy_subject).and_return(can_admin)
      end

      it 'returns the expected result' do
        expect(helper.show_virtual_registries_setting?(group)).to eq(expected_result)
      end
    end
  end
end
