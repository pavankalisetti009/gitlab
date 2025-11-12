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

    describe 'access to foundational chat agents' do
      let(:foundational_agents_default_enabled) { true }

      context 'when is saas' do
        let(:default_namespace) { create(:group) }

        before do
          allow(current_user.user_preference).to receive(:get_default_duo_namespace).and_return(default_namespace)
          allow(default_namespace).to receive(:foundational_agents_default_enabled)
                                        .and_return(foundational_agents_default_enabled)
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        context 'when user default namespace has access to foundational chat agents' do
          it 'returns all agents' do
            expect(resolved.size).to eq(::Ai::FoundationalChatAgent.all.size)
          end
        end

        context 'when user default namespace does not have access to foundational chat agents' do
          let(:foundational_agents_default_enabled) { false }

          it 'returns only duo chat' do
            expect(resolved).to match_array(::Ai::FoundationalChatAgent.only_duo_chat_agent)
          end
        end
      end

      context 'when is self-managed' do
        before do
          ::Ai::Setting.instance.update!(foundational_agents_default_enabled: foundational_agents_default_enabled)
        end

        context 'when application settings have foundational chat agents set to enabled by default' do
          it 'is returns all agents' do
            expect(resolved.size).to eq(::Ai::FoundationalChatAgent.all.size)
          end
        end

        context 'when application settings have foundational chat agents set to disabled by default' do
          let(:foundational_agents_default_enabled) { false }

          it 'is returns only duo chat' do
            expect(resolved).to match_array(::Ai::FoundationalChatAgent.only_duo_chat_agent)
          end
        end
      end
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

    context 'when foundational_analytics_agent feature flag is disabled' do
      before do
        stub_feature_flags(foundational_analytics_agent: false)
      end

      it 'filters out analytics_agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).not_to include('analytics_agent')
      end
    end

    context 'when foundational_analytics_agent feature flag is enabled' do
      before do
        stub_feature_flags(foundational_analytics_agent: true)
      end

      it 'includes analytics_agent' do
        agent_references = resolved.map(&:reference)

        expect(agent_references).to include('analytics_agent')
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
