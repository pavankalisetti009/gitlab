# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FoundationalChatAgentsResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  describe '#resolve' do
    subject(:resolved) do
      resolve(described_class, args: { project_id: nil, namespace_id: nil }, ctx: { current_user: current_user }).to_a
    end

    it 'returns a list of foundational chat agents sorted by id' do
      expect(resolved).to eq(resolved.sort_by(&:id))
      expect(resolved[0].name).to eq('GitLab Duo Agent')
    end

    context 'when foundational_duo_planner feature flag is disabled' do
      before do
        stub_feature_flags(foundational_duo_planner: false)
      end

      it 'filters out duo_planner agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).not_to include('duo_planner')
      end
    end

    context 'when foundational_duo_planner feature flag is enabled' do
      before do
        stub_feature_flags(foundational_duo_planner: true)
      end

      it 'includes duo_planner agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).to include('duo_planner')
      end
    end

    context 'when foundational_security_agent feature flag is disabled' do
      before do
        stub_feature_flags(foundational_security_agent: false)
      end

      it 'filters out security_analyst_agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).not_to include('security_analyst_agent')
      end
    end

    context 'when foundational_security_agent feature flag is enabled' do
      before do
        stub_feature_flags(foundational_security_agent: true)
      end

      it 'includes security_analyst_agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).to include('security_analyst_agent')
      end
    end
  end

  describe 'arguments' do
    subject(:arguments) { described_class.arguments }

    it 'accepts namespace_id and project_id' do
      expect(arguments).to include('namespaceId', 'projectId')
    end
  end
end
