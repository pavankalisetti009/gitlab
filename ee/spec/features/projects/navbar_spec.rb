# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project navbar', :js, feature_category: :navigation do
  include NavbarStructureHelper

  include_context 'project navbar structure'

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, namespace: user.namespace) }

  before_all do
    project.update!(duo_remote_flows_enabled: true)
  end

  before do
    project.add_owner(user)

    sign_in(user)

    stub_config(registry: { enabled: false })
    stub_feature_flags(agent_registry: false)
    stub_feature_flags(remove_monitor_metrics: false)
    stub_feature_flags(hide_incident_management_features: false)
    insert_package_nav
    insert_infrastructure_registry_nav(s_('Terraform|Terraform states'))
    insert_infrastructure_google_cloud_nav
    insert_infrastructure_aws_nav
    project.update!(service_desk_enabled: true)
    allow(::ServiceDesk).to receive(:supported?).and_return(true)

    allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(product_analytics_features: true)
  end

  describe 'when hide_error_tracking_features is disabled' do
    before do
      stub_feature_flags(hide_error_tracking_features: false)
    end

    context 'with default navbar' do
      before do
        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when iterations is available' do
      before do
        stub_licensed_features(iterations: true, product_analytics: true)
      end

      context 'when project is namespaced to a user' do
        before do
          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end

      context 'when project is namespaced to a group' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, :repository, group: group) }

        before do
          group.add_developer(user)
          project.update!(duo_remote_flows_enabled: true)

          insert_after_sub_nav_item(
            _('Milestones'),
            within: _('Plan'),
            new_sub_nav_item_name: _('Iterations')
          )

          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar' do
          let(:expected_structure) do
            group_owned_structure.compact!
            group_owned_structure.each { |s| s[:nav_sub_items]&.compact! }
            group_owned_structure
          end
        end
      end
    end

    context 'when issue analytics is available' do
      before do
        stub_licensed_features(issues_analytics: true)

        insert_after_sub_nav_item(
          _('Merge request analytics'),
          within: _('Analyze'),
          new_sub_nav_item_name: _('Issue analytics')
        )

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when Automate is available' do
      before do
        # Mock duo_workflow permissions for navbar tests
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
        allow(user).to receive(:can?).with(:manage_ai_flow_triggers, project).and_return(false)

        # Mock the underlying requirements for duo_workflow permission
        stub_feature_flags(duo_workflow: true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(false) # Default to false
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(kind_of(ProjectPresenter),
          :duo_workflow).and_return(true)
        allow(user).to receive(:allowed_to_use?).and_return(false) # Default to false
        allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform).and_return(true)

        insert_after_nav_item(
          _('Plan'),
          new_nav_item: {
            nav_item: _('Automate'),
            nav_sub_items: [
              s_('AICatalog|Agents'),
              s_('AICatalog|Flows'),
              s_('DuoAgentsPlatform|Sessions')
            ]
          }
        )

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when security dashboard is available' do
      let(:secure_nav_item) do
        {
          nav_item: _('Secure'),
          nav_sub_items: [
            _('Security dashboard'),
            _('Vulnerability report'),
            _('Audit events'),
            s_('OnDemandScans|On-demand scans'),
            _('Security configuration')
          ]
        }
      end

      before do
        stub_licensed_features(security_dashboard: true, security_on_demand_scans: true)

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'

      context 'when FIPS mode is enabled' do
        let(:nav_sub_items) do
          [
            _('Security dashboard'),
            _('Vulnerability report'),
            _('Audit events'),
            _('On-demand scans'),
            _('Security configuration')
          ]
        end

        let(:secure_nav_item) { { nav_item: _('Secure'), nav_sub_items: nav_sub_items } }

        before do
          allow(::Gitlab::FIPS).to receive(:enabled?).and_return(true)
          stub_licensed_features(security_dashboard: true, security_on_demand_scans: true)
          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end
    end

    context 'when secrets manager is available' do
      let_it_be(:secrets_manager) { build(:project_secrets_manager, project: project) }

      let(:secure_nav_item) do
        {
          nav_item: _('Secure'),
          nav_sub_items: [
            _('Audit events'),
            _('Security configuration'),
            _('Secrets manager')
          ]
        }
      end

      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager: true)
        secrets_manager.activate!

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when secrets manager is not available' do
      let_it_be(:secrets_manager) { build(:project_secrets_manager, project: project) }

      before_all do
        stub_feature_flags(secrets_manager: true)
        secrets_manager.activate!
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager: false)
          stub_licensed_features(native_secrets_management: true)
          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end

      context 'when feature license is disabled' do
        before do
          stub_licensed_features(native_secrets_management: false)
          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end

      context 'when secrets manager is not active' do
        before do
          stub_licensed_features(native_secrets_management: true)
          secrets_manager.update!(status: SecretsManagement::ProjectSecretsManager::STATUSES[:deprovisioning])
          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end
    end

    context 'when packages are available' do
      before do
        stub_config(packages: { enabled: true }, registry: { enabled: false })

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when container registry is available' do
      before do
        stub_config(registry: { enabled: true })

        insert_container_nav

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when google artifact registry is available' do
      let_it_be(:artifact_registry_integration) do
        create(:google_cloud_platform_artifact_registry_integration, project: project)
      end

      let_it_be(:wlif_integration) do
        create(:google_cloud_platform_workload_identity_federation_integration, project: project)
      end

      before do
        stub_config(registry: { enabled: true })
        stub_saas_features(google_cloud_support: true)

        insert_container_nav
        insert_google_artifact_registry_nav

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when google artifact registry is unavailable' do
      before do
        stub_config(packages: { enabled: true }, registry: { enabled: true })
        stub_saas_features(google_cloud_support: false)

        insert_container_nav

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when harbor registry is available' do
      let(:harbor_integration) { create(:harbor_integration) }

      before do
        project.update!(harbor_integration: harbor_integration)

        insert_harbor_registry_nav

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when analytics dashboards is available' do
      before do
        stub_licensed_features({ project_level_analytics_dashboard: true, product_analytics: true,
  iterations: false })

        visit project_path(project)
      end

      context 'when project is namespaced to a user' do
        it_behaves_like 'verified navigation bar'
      end

      context 'when project is namespaced to a group' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, :repository, group: group) }

        before_all do
          project.add_maintainer(user)
          project.update!(duo_remote_flows_enabled: true)
        end

        before do
          insert_before_sub_nav_item(
            _('Value stream analytics'),
            within: _('Analyze'),
            new_sub_nav_item_name: _('Analytics dashboards')
          )

          insert_after_sub_nav_item(
            _('Monitor'),
            within: _('Settings'),
            new_sub_nav_item_name: _('Analytics')
          )

          visit project_path(project)
        end

        it_behaves_like 'verified navigation bar'
      end
    end

    context 'when AI agents is available' do
      before do
        stub_feature_flags(agent_registry: true, agent_registry_nav: true)
        stub_licensed_features(ai_agents: true)

        insert_ai_agents_nav(_('Model registry'))

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end
  end

  describe 'when hide_error_tracking_features is enabled' do
    context 'when error tracking feature flag is enabled' do
      before do
        remove_nav_item(_('Error Tracking'))

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end
  end
end
