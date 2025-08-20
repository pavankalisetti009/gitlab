# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::WrappedAgentFlowBuilder, :aggregate_failures, feature_category: :duo_workflow do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let(:builder) { described_class.new(agent, agent_version) }

  describe 'validation' do
    context 'when agent is nil' do
      let(:builder) { described_class.new(nil, agent_version) }

      it 'raises an ArgumentError' do
        expect { builder.build }.to raise_error(ArgumentError, 'Agent is required')
      end
    end

    context 'when wrong item type is passed as agent' do
      let(:flow) { build(:ai_catalog_flow, organization: organization, project: project) }
      let(:flow_version) { flow.versions.last }
      let(:builder) { described_class.new(flow, flow_version) }

      it 'raises an ArgumentError' do
        expect { builder.build }.to raise_error(ArgumentError, 'Agent is required')
      end
    end

    context 'when agent_version is nil' do
      let(:builder) { described_class.new(agent, nil) }

      it 'raises an ArgumentError' do
        expect { builder.build }.to raise_error(ArgumentError, 'Agent version is required')
      end
    end

    context 'when agent_version does not belong to the agent' do
      let(:other_agent) { build(:ai_catalog_agent, organization: organization, project: project) }
      let(:other_agent_version) { other_agent.versions.last }
      let(:builder) { described_class.new(agent, other_agent_version) }

      it 'raises an ArgumentError' do
        expect { builder.build }.to raise_error(ArgumentError, 'Agent version must belong to the agent')
      end
    end
  end

  describe 'constants' do
    it 'defines the correct generated flow version' do
      expect(described_class::GENERATED_FLOW_VERSION).to eq('1.0.0')
    end
  end

  describe '#build' do
    subject(:build) { builder.build }

    it 'returns a flow item with the correct attributes' do
      flow = build

      expect(flow).to be_a(::Ai::Catalog::Item)
      expect(flow.item_type).to eq(::Ai::Catalog::Item::FLOW_TYPE.to_s)
      expect(flow).to be_readonly
    end

    it 'creates a flow version with the correct attributes' do
      flow = build
      flow_version = flow.versions.last

      expect(flow_version).to be_a(::Ai::Catalog::ItemVersion)
      expect(flow_version.schema_version).to eq(::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION)
      expect(flow_version.version).to eq(described_class::GENERATED_FLOW_VERSION)
    end

    it 'creates a flow definition with the correct structure' do
      flow = build
      flow_version = flow.versions.first
      definition = flow_version.definition

      expect(definition).to eq({
        "triggers" => [],
        "steps" => [
          {
            "agent_id" => agent.id,
            "current_version_id" => agent_version.id,
            "pinned_version_prefix" => nil
          }
        ]
      })
    end
  end
end
