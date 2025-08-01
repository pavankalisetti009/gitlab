# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::V1, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:agent_item_2) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:tool_ids) { [1, 2, 5] }

  let_it_be(:agent_definition) do
    {
      'system_prompt' => 'Talk like a pirate!',
      'user_prompt' => "What is a leap year?",
      'tools' => tool_ids
    }
  end

  let_it_be(:flow_definition) do
    {
      'triggers' => [1],
      'steps' => [
        { 'agent_id' => agent_item_1.id },
        { 'agent_id' => agent_item_2.id }
      ]
    }
  end

  let_it_be(:flow_version) do
    create(:ai_catalog_flow_version, item: flow_item, definition: flow_definition, version: '2.1.0')
  end

  let_it_be(:agent_version_1) do
    create(:ai_catalog_agent_version, item: agent_item_1, definition: agent_definition, version: '1.1.0')
  end

  let_it_be(:agent_version_2) do
    create(:ai_catalog_agent_version, item: agent_item_2, definition: agent_definition, version: '1.1.1')
  end

  subject(:builder) { described_class.new(flow_item.id, nil) }

  describe 'inheritance' do
    it 'inherits from Base' do
      expect(described_class.superclass).to eq(Ai::Catalog::DuoWorkflowPayloadBuilder::Base)
    end
  end

  describe 'constants' do
    it 'defines expected constants' do
      expect(described_class::FLOW_VERSION).to eq('experimental')
      expect(described_class::FLOW_ENVIRONMENT).to eq('remote')
      expect(described_class::AGENT_COMPONENT_TYPE).to eq('AgentComponent')
      expect(described_class::OUTPUT_CONTEXT).to eq('context:agent.answer')
    end
  end

  shared_examples 'builds valid flow configuration' do
    let(:result) { builder.build }

    it 'returns correct flow configuration structure' do
      expect(result).to include(
        'version' => 'experimental',
        'environment' => 'remote',
        'components' => be_an(Array),
        'routers' => be_an(Array),
        'flow' => be_a(Hash)
      )
    end

    it 'builds components with correct structure' do
      expect(result['components']).to all(include(
        'name' => be_a(String),
        'type' => 'AgentComponent',
        'prompt_id' => 'workflow_catalog',
        'prompt_version' => '^1.0.0',
        'inputs' => be_an(Array),
        'output' => 'context:agent.answer',
        'toolset' => be_an(Array)
      ))
    end
  end

  shared_examples 'invalid flow configuration' do
    it 'raises error during build' do
      expect { builder.build }.to raise_error(StandardError)
    end
  end

  describe '#build' do
    context 'when flow has no versions' do
      let_it_be(:empty_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:builder) { described_class.new(empty_flow.id, nil) }

      it_behaves_like 'invalid flow configuration'
    end

    context 'when flow has no agents' do
      let_it_be(:empty_steps_definition) { { 'triggers' => [1], 'steps' => [] } }
      let_it_be(:empty_steps_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:empty_steps_version) do
        create(:ai_catalog_flow_version, item: empty_steps_flow, definition: empty_steps_definition,
          version: '2.1.0')
      end

      let_it_be(:builder) { described_class.new(empty_steps_flow.id, nil) }

      it_behaves_like 'invalid flow configuration'
    end

    context 'when flow have single agent' do
      let_it_be(:single_agent_flow_definition) do
        {
          'triggers' => [1],
          'steps' => [{ 'agent_id' => agent_item_1.id }]
        }
      end

      let_it_be(:single_agent_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:single_agent_flow_version) do
        create(:ai_catalog_flow_version, item: single_agent_flow, definition: single_agent_flow_definition,
          version: '2.2.0')
      end

      let_it_be(:builder) { described_class.new(single_agent_flow.id) }

      include_examples 'builds valid flow configuration'

      it 'builds workflow with single component and routers', :aggregate_failures do
        result = builder.build

        expect(result['components'].size).to eq(1)
        expect(result['flow']['entry_point']).to eq(agent_item_1.id.to_s)
        expect(result['routers']).to eq([
          { 'from' => agent_item_1.id.to_s, 'to' => 'end' }
        ])
      end
    end

    context 'when flow has multiple agents' do
      let(:result) { builder.build }

      include_examples 'builds valid flow configuration'

      it 'builds workflow with multiple components and routers', :aggregate_failures do
        expect(result['components'].size).to eq(2)
        expect(result['routers'].size).to eq(2)
        expect(result['flow']['entry_point']).to eq(agent_item_1.id.to_s)
      end

      it 'creates routers connecting agents sequentially' do
        expect(result['routers']).to eq([
          { 'from' => agent_item_1.id.to_s, 'to' => agent_item_2.id.to_s },
          { 'from' => agent_item_2.id.to_s, 'to' => 'end' }
        ])
      end

      it 'verifies all components have unique names' do
        component_names = result['components'].pluck('name')

        expect(component_names).to contain_exactly(
          agent_item_1.id.to_s,
          agent_item_2.id.to_s
        )
      end
    end
  end
end
