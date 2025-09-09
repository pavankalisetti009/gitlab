# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::ChatFlow, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  subject(:builder) { described_class.new(flow, flow_version, pinned_version_prefix) }

  describe 'inheritance' do
    it 'inherits from ExperimentalAgentWrapper' do
      expect(described_class.superclass).to eq(Ai::Catalog::DuoWorkflowPayloadBuilder::ExperimentalAgentWrapper)
    end
  end

  describe 'constants' do
    it 'defines FLOW_ENVIRONMENT constant' do
      expect(described_class::FLOW_ENVIRONMENT).to eq('chat-partial')
    end
  end

  describe '#build' do
    let(:wrapped_agent_response) { Ai::Catalog::WrappedAgentFlowBuilder.new(agent, agent_version).execute }
    let(:flow) { wrapped_agent_response.payload[:flow] }
    let(:flow_version) { flow.versions.last }
    let(:pinned_version_prefix) { nil }

    it_behaves_like 'builds valid flow configuration' do
      let(:result) { builder.build }
      let(:environment) { 'chat-partial' }
      let(:version) { 'experimental' }
    end

    it 'has empty routers and flow' do
      result = builder.build
      expect(result['routers']).to eq([])
      expect(result['flow']).to eq({})
    end
  end
end
