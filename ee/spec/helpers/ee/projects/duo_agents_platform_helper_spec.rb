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
      allow(helper).to receive(:image_path).with(
        'illustrations/empty-state/empty-pipeline-md.svg')
        .and_return('/assets/illustrations/empty-state/empty-pipeline-md.svg'
                   )
    end

    it 'returns the expected data hash' do
      expected_data = {
        agents_platform_base_route: '/test-project/-/automate',
        project_path: project.full_path,
        project_id: project.id,
        explore_ai_catalog_path: '/explore/ai-catalog',
        flow_triggers_event_type_options: [
          { 'text' => 'Mention', 'value' => 0 },
          { 'text' => 'Assign', 'value' => 1 },
          { 'text' => 'Assign reviewer', 'value' => 2 }
        ].to_json
      }

      expect(helper_data).to eq(expected_data)
    end
  end
end
