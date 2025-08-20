# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::ExperimentalAgentWrapper, :aggregate_failures, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_version) { agent.versions.last }
  let_it_be(:flow) { Ai::Catalog::WrappedAgentFlowBuilder.new(agent, agent_version).build }
  let_it_be(:flow_version) { flow.versions.last }
  let_it_be(:pinned_version_prefix) { nil }

  subject(:builder) { described_class.new(flow, flow_version, nil) }

  describe 'inheritance' do
    it 'inherits from Experimental' do
      expect(described_class.superclass).to eq(Ai::Catalog::DuoWorkflowPayloadBuilder::Experimental)
    end
  end

  describe '#initialize' do
    it 'sets flow_version and calls super' do
      expect(builder.instance_variable_get(:@flow_version)).to eq(flow_version)
      expect(builder.instance_variable_get(:@flow)).to eq(flow)
      expect(builder.instance_variable_get(:@pinned_version_prefix)).to eq(pinned_version_prefix)
    end
  end

  describe '#build' do
    let(:result) { builder.build }

    it_behaves_like 'builds valid flow configuration'
  end
end
