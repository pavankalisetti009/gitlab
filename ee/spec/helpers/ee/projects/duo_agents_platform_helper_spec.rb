# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::DuoAgentsPlatformHelper, feature_category: :duo_agent_platform do
  include Rails.application.routes.url_helpers

  let_it_be(:group) { build_stubbed(:group, name: 'Test Group') }
  let_it_be(:project) { build_stubbed(:project, name: 'Test Project', group: group) }

  before do
    helper.instance_variable_set(:@project, project)
  end

  describe '#duo_agents_platform_data' do
    subject(:helper_data) { helper.duo_agents_platform_data(project) }

    before do
      allow(helper).to receive(:project_automate_path).with(project).and_return('/test-project/-/automate')
      allow(helper).to receive(:project_analytics_dashboards_path)
                         .with(project, vueroute: 'duo_and_sdlc_trends')
                         .and_return('/test-project/-/analytics/dashboards/duo_and_sdlc_trends')
      allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(true)
    end

    it 'returns the expected data hash' do
      expected_data = {
        agents_platform_base_route: '/test-project/-/automate',
        root_group_id: project.root_namespace.id,
        project_path: project.full_path,
        project_id: project.id,
        explore_ai_catalog_path: '/explore/ai-catalog',
        ai_impact_dashboard_enabled: 'true',
        ai_impact_dashboard_path: '/test-project/-/analytics/dashboards/duo_and_sdlc_trends'
      }

      expect(helper_data).to eq(expected_data)
    end

    context 'when project is personal' do
      let_it_be(:project) { build_stubbed(:project, :in_user_namespace) }

      it 'returns root_group_id as nil' do
        expect(helper_data).to include(
          root_group_id: nil,
          project_id: project.id,
          project_path: project.full_path
        )
      end
    end

    context 'when AI impact dashboard is not available' do
      before do
        allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(false)
      end

      it 'returns ai_impact_dashboard_enabled as false and ai_impact_dashboard_path as nil' do
        expect(helper_data).to include(
          ai_impact_dashboard_enabled: 'false',
          ai_impact_dashboard_path: nil
        )
      end
    end
  end

  describe '#duo_agents_group_data' do
    subject(:helper_data) { helper.duo_agents_group_data(group) }

    before do
      allow(helper).to receive(:group_automate_path).with(group).and_return('/test-group/-/automate')
      allow(helper).to receive(:group_analytics_dashboards_path)
                         .with(group, vueroute: 'duo_and_sdlc_trends')
                         .and_return('/groups/test_group/-/analytics/dashboards/duo_and_sdlc_trends')
      allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(true)
    end

    it 'returns the expected data hash' do
      expected_data = {
        agents_platform_base_route: '/test-group/-/automate',
        group_path: group.full_path,
        group_id: group.id,
        explore_ai_catalog_path: '/explore/ai-catalog',
        ai_impact_dashboard_enabled: 'true',
        ai_impact_dashboard_path: '/groups/test_group/-/analytics/dashboards/duo_and_sdlc_trends'
      }

      expect(helper_data).to eq(expected_data)
    end

    context 'when AI impact dashboard is not available' do
      before do
        allow(ProductAnalyticsHelpers).to receive(:ai_impact_dashboard_globally_available?).and_return(false)
      end

      it 'returns ai_impact_dashboard_enabled as false and ai_impact_dashboard_path as nil' do
        expect(helper_data).to include(
          ai_impact_dashboard_enabled: 'false',
          ai_impact_dashboard_path: nil
        )
      end
    end
  end
end
