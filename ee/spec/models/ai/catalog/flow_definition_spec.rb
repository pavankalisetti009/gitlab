# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::FlowDefinition, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow) }
  let_it_be(:agent_1) { create(:ai_catalog_agent) }
  let_it_be(:agent_2) { create(:ai_catalog_agent) }
  let_it_be(:definition) do
    {
      'triggers' => [1],
      'steps' =>
      [
        { 'agent_id' => agent_1.id, 'current_version_id' => agent_1.latest_version.id, 'pinned_version_prefix' => nil },
        { 'agent_id' => agent_2.id, 'current_version_id' => agent_2.latest_version.id, 'pinned_version_prefix' => nil }
      ]
    }
  end

  let_it_be(:flow_version) do
    create(:ai_catalog_flow_version, item: flow_item, definition: definition, version: '1.1.0')
  end

  subject(:flow_definition) { described_class.new(flow_item, flow_version) }

  describe 'inheritance' do
    it 'inherits from BaseDefinition' do
      expect(described_class.superclass).to eq(Ai::Catalog::BaseDefinition)
    end
  end

  describe '#steps_with_agents_preloaded' do
    it 'returns agent version mappings for existing agents' do
      mappings = flow_definition.steps_with_agents_preloaded

      expect(mappings).to contain_exactly(
        { agent: agent_1, current_version_id: agent_1.latest_version.id, pinned_version_prefix: nil },
        { agent: agent_2, current_version_id: agent_2.latest_version.id, pinned_version_prefix: nil }
      )
    end
  end

  describe '#agents' do
    it 'returns unique agents from the workflow steps' do
      agents = flow_definition.agents

      expect(agents).to contain_exactly(agent_1, agent_2)
    end
  end
end
