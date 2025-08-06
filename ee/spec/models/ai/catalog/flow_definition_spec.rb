# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::FlowDefinition, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_item, :flow, :with_version) }
  let_it_be(:agent_item_1) { create(:ai_catalog_item, :agent, :with_version) }
  let_it_be(:agent_item_2) { create(:ai_catalog_item, :agent, :with_version) }
  let_it_be(:definition) do
    {
      'triggers' => [1],
      'steps' =>
      [
        { 'agent_id' => agent_item_1.id },
        { 'agent_id' => agent_item_2.id }
      ]
    }
  end

  let_it_be(:flow_version) do
    create(:ai_catalog_flow_version, item: flow_item, definition: definition, version: '1.1.0')
  end

  subject(:flow_definition) { described_class.new(flow_item, nil) }

  describe 'inheritance' do
    it 'inherits from BaseDefinition' do
      expect(described_class.superclass).to eq(Ai::Catalog::BaseDefinition)
    end
  end

  describe '#agent_version_mappings' do
    it 'returns agent version mappings for existing agents' do
      mappings = flow_definition.agent_version_mappings

      expect(mappings).to contain_exactly(
        { agent: agent_item_1, version: nil },
        { agent: agent_item_2, version: nil }
      )
    end
  end

  describe '#agents' do
    it 'returns unique agents from the workflow steps' do
      agents = flow_definition.agents

      expect(agents).to contain_exactly(agent_item_1, agent_item_2)
    end
  end
end
