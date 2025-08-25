# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::Experimental, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:agent_item_2) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:tool_ids) { [1, 2, 5] } # 1 => "gitlab_blob_search" 2 => 'ci_linter', 5 =>  'create_epic'

  let_it_be(:agent_definition) do
    {
      'system_prompt' => 'Talk like a pirate!',
      'user_prompt' => "What is a leap year?",
      'tools' => tool_ids
    }
  end

  let_it_be(:agent1_v1) do
    create(:ai_catalog_agent_version, item: agent_item_1, definition: agent_definition, version: '1.1.0')
  end

  let_it_be(:agent2_v1) do
    create(:ai_catalog_agent_version, item: agent_item_2, definition: agent_definition, version: '1.1.1')
  end

  let_it_be(:agent2_v2) do
    definition = agent_definition.merge('tools' => [3]) # 3 => 'run_git_command'
    create(:ai_catalog_agent_version, item: agent_item_2, definition: definition, version: '1.2.0')
  end

  let_it_be(:flow_definition) do
    {
      'triggers' => [1],
      'steps' => [
        { 'agent_id' => agent_item_1.id, 'current_version_id' => agent1_v1.id, 'pinned_version_prefix' => nil },
        { 'agent_id' => agent_item_2.id, 'current_version_id' => agent2_v1.id, 'pinned_version_prefix' => nil }
      ]
    }
  end

  let_it_be(:flow_version) do
    create(:ai_catalog_flow_version, item: flow_item, definition: flow_definition, version: '2.1.0')
  end

  subject(:builder) { described_class.new(flow_item) }

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
    end
  end

  describe '#build' do
    context 'when flow has no versions' do
      let_it_be(:empty_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:builder) { described_class.new(empty_flow) }

      it_behaves_like 'invalid flow configuration'
    end

    context 'when flow has no agents' do
      let_it_be(:empty_steps_definition) { { 'triggers' => [1], 'steps' => [] } }
      let_it_be(:empty_steps_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:empty_steps_version) do
        create(:ai_catalog_flow_version, item: empty_steps_flow, definition: empty_steps_definition,
          version: '2.1.0')
      end

      let_it_be(:builder) { described_class.new(empty_steps_flow) }

      it_behaves_like 'invalid flow configuration'
    end

    context 'when flow have single agent' do
      let_it_be_with_reload(:single_agent_flow) { create(:ai_catalog_flow, project: project) }

      let_it_be(:single_agent_flow_definition) do
        {
          'triggers' => [1],
          'steps' => [{
            'agent_id' => agent_item_1.id, 'current_version_id' => agent1_v1.id, 'pinned_version_prefix' => nil
          }]
        }
      end

      let_it_be(:single_agent_flow_version) do
        create(:ai_catalog_flow_version, item: single_agent_flow, definition: single_agent_flow_definition,
          version: '2.2.0')
      end

      let(:builder) { described_class.new(single_agent_flow) }
      let(:result) { builder.build }

      include_examples 'builds valid flow configuration'

      it 'builds workflow with single component correctly', :aggregate_failures do
        agent_item_1_flow_id = "#{agent_item_1.id}/0"
        result = builder.build

        expect(result['components']).to eq([
          {
            'name' => agent_item_1_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => 'workflow_catalog',
            'prompt_version' => '^1.0.0',
            'inputs' => [{ 'from' => 'context:goal', 'as' => 'goal' }],
            'toolset' => %w[gitlab_blob_search ci_linter create_epic],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          }
        ])
        expect(result['flow']['entry_point']).to eq(agent_item_1_flow_id)
        expect(result['routers']).to eq([
          { 'from' => agent_item_1_flow_id, 'to' => 'end' }
        ])
      end

      describe 'version handling' do
        let_it_be(:new_flow_version) do
          definition = {
            'triggers' => [],
            'steps' => [{
              'agent_id' => agent_item_2.id, 'current_version_id' => agent2_v1.id, 'pinned_version_prefix' => nil
            }]
          }
          create(:ai_catalog_flow_version, item: single_agent_flow, definition: definition, version: '2.3.0')
        end

        context 'when no version is pinned' do
          it 'selects the latest flow version' do
            result = described_class.new(single_agent_flow).build

            expect(result['flow']['entry_point']).to eq("#{agent_item_2.id}/0")
          end
        end

        context 'when flow version prefix is pinned' do
          it 'selects the correct flow version' do
            result = described_class.new(single_agent_flow, '2.3').build

            expect(result['flow']['entry_point']).to eq("#{agent_item_2.id}/0")
            expect(result['components'].first['toolset']).to contain_exactly('run_git_command')
          end
        end

        context 'when flow version is fully pinned' do
          it 'selects the correct flow version and child versions' do
            result = described_class.new(single_agent_flow, '2.3.0').build

            expect(result['flow']['entry_point']).to eq("#{agent_item_2.id}/0")
            expect(result['components'].first['toolset']).to contain_exactly(
              'ci_linter', 'create_epic', 'gitlab_blob_search'
            )
          end
        end
      end
    end

    context 'when flow has multiple agents' do
      let(:result) { builder.build }

      include_examples 'builds valid flow configuration'

      it 'builds workflow with multiple components correctly', :aggregate_failures do
        agent_item_1_flow_id = "#{agent_item_1.id}/0"
        agent_item_2_flow_id = "#{agent_item_2.id}/1"

        expect(result['components']).to eq([
          {
            'name' => agent_item_1_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => 'workflow_catalog',
            'prompt_version' => '^1.0.0',
            'inputs' => [{ 'from' => 'context:goal', 'as' => 'goal' }],
            'toolset' => %w[gitlab_blob_search ci_linter create_epic],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          },
          {
            'name' => agent_item_2_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => 'workflow_catalog',
            'prompt_version' => '^1.0.0',
            'inputs' => [
              { 'from' => 'context:goal', 'as' => 'goal' },
              { 'from' => "context:#{agent_item_1_flow_id}.final_answer", 'as' => 'previous_step_answer' },
              { 'from' => "conversation_history:#{agent_item_1_flow_id}", 'as' => 'previous_step_msg_history' }
            ],
            'toolset' => %w[run_git_command],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          }
        ])
        expect(result['routers']).to eq([
          { 'from' => agent_item_1_flow_id, 'to' => agent_item_2_flow_id },
          { 'from' => agent_item_2_flow_id, 'to' => 'end' }
        ])
        expect(result['flow']['entry_point']).to eq(agent_item_1_flow_id)
      end

      it 'verifies all components have unique names' do
        component_names = result['components'].pluck('name')

        expect(component_names).to contain_exactly(
          "#{agent_item_1.id}/0",
          "#{agent_item_2.id}/1"
        )
      end
    end
  end
end
