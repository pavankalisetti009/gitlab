# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FoundationalChatAgentsResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_namespace_foundational_agents_enabled) { create(:group) }
  let_it_be(:namespace_ai_settings) do
    create(:namespace_ai_settings,
      foundational_agents_default_enabled: true,
      namespace: root_namespace_foundational_agents_enabled)
  end

  let_it_be(:subgroup1) { create(:group, parent: root_namespace_foundational_agents_enabled) }
  let_it_be(:project1) { create(:project, namespace: subgroup1) }
  let_it_be(:root_namespace_foundational_agents_disabled) { create(:group) }
  let_it_be(:subgroup2) { create(:group, parent: root_namespace_foundational_agents_disabled) }
  let_it_be(:project2) { create(:project, namespace: subgroup2) }

  shared_examples 'returns only duo chat' do
    it 'returns only duo chat' do
      expect(resolved).to match_array(::Ai::FoundationalChatAgent.only_duo_chat_agent)
    end
  end

  shared_examples 'returns all foundational agents' do
    it 'returns all agents' do
      expect(resolved.size).to eq(::Ai::FoundationalChatAgent.all.size)
    end
  end

  shared_examples 'returns full list if feature flag is enabled for namespace' do
    context 'when duo_foundational_agents_availability is enabled for root namespace' do
      it_behaves_like 'returns all foundational agents'
    end

    context 'when duo_foundational_agents_availability is disabled for root_namespace' do
      before do
        stub_feature_flags(duo_foundational_agents_availability: [root_namespace_foundational_agents_disabled])
      end

      it_behaves_like 'returns only duo chat'
    end
  end

  describe '#resolve' do
    let(:project) { nil }
    let(:namespace) { nil }

    subject(:resolved) do
      response = resolve(described_class, args: { project_id: project&.to_gid, namespace_id: namespace&.to_gid },
        ctx: { current_user: current_user })

      response.to_a
    end

    it 'returns a list of foundational chat agents sorted by id' do
      expect(resolved).to eq(resolved.sort_by(&:id))
      expect(resolved[0].name).to eq('GitLab Duo')
    end

    context 'when user is not set' do
      let(:current_user) { nil }

      context 'when is saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it_behaves_like 'returns only duo chat'
      end

      context 'when is self-managed' do
        it_behaves_like 'returns all foundational agents'
      end
    end

    describe 'access to foundational chat agents' do
      context 'when is saas' do
        let(:default_namespace) { root_namespace_foundational_agents_enabled }
        let(:project) { nil }
        let(:namespace) { nil }

        before do
          allow(root_namespace_foundational_agents_enabled).to receive(:foundational_agents_default_enabled)
                                                                 .and_return(true)

          allow(current_user.user_preference)
            .to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
          stub_saas_features(gitlab_com_subscriptions: true)

          stub_feature_flags(duo_foundational_agents_availability: [root_namespace_foundational_agents_enabled,
            root_namespace_foundational_agents_disabled])

          allow(::Ability).to receive(:allowed?).and_call_original
          allow(::Ability).to receive(:allowed?).with(current_user, :read_namespace,
            root_namespace_foundational_agents_enabled).and_return(true)
          allow(::Ability).to receive(:allowed?).with(current_user, :read_namespace,
            root_namespace_foundational_agents_disabled).and_return(true)
          allow(::Ability).to receive(:allowed?).with(current_user, :read_project, project1).and_return(true)
          allow(::Ability).to receive(:allowed?).with(current_user, :read_project, project2).and_return(true)
        end

        context 'when user has default namespace' do
          context 'with access to foundational chat agents' do
            it_behaves_like 'returns full list if feature flag is enabled for namespace'
          end

          context 'without access to foundational chat agents' do
            let(:default_namespace) { root_namespace_foundational_agents_disabled }

            context 'when project_id top namespace has access to foundational chat agents' do
              let(:project) { project1 }

              it_behaves_like 'returns only duo chat'
            end

            context 'when namespace_id top namespace has access to foundational chat agents' do
              let(:project) { project2 }

              it_behaves_like 'returns only duo chat'
            end
          end
        end

        context 'when user default namespace does not exist' do
          let(:default_namespace) { nil }

          context 'and project top namespace has foundational agents enabled' do
            let(:project) { project1 }

            context 'and user can read project' do
              it_behaves_like 'returns full list if feature flag is enabled for namespace'
            end

            context 'and user cannot read project' do
              before do
                allow(::Ability).to receive(:allowed?).with(current_user, :read_project, project1).and_return(false)
              end

              it_behaves_like 'returns only duo chat'
            end
          end

          context 'and namespace top namespace has foundational agents enabled' do
            let(:namespace) { subgroup1 }

            context 'and user can read namespace' do
              it_behaves_like 'returns full list if feature flag is enabled for namespace'
            end

            context 'and user cannot read namespace' do
              before do
                allow(::Ability).to receive(:allowed?).with(current_user, :read_namespace,
                  root_namespace_foundational_agents_enabled).and_return(false)
              end

              it_behaves_like 'returns only duo chat'
            end
          end

          context 'when neither project_id nor namespace_id are passed' do
            it_behaves_like 'returns only duo chat'
          end
        end
      end

      context 'when is self-managed' do
        let(:foundational_agents_default_enabled) { true }

        before do
          ::Ai::Setting.instance.update!(foundational_agents_default_enabled: foundational_agents_default_enabled)
        end

        context 'when application settings have foundational chat agents set to enabled by default' do
          it_behaves_like 'returns all foundational agents'
        end

        context 'when application settings have foundational chat agents set to disabled by default' do
          let(:foundational_agents_default_enabled) { false }

          it_behaves_like 'returns only duo chat'
        end

        context 'when duo_foundational_agents_availability is off' do
          before do
            stub_feature_flags(duo_foundational_agents_availability: false)
          end

          it_behaves_like 'returns only duo chat'
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
