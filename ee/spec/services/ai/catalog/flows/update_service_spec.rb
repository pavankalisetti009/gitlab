# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, item_type: :flow, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_flow_version, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) { create(:ai_catalog_flow_version, version: '1.1.0', item: item) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_v1_0) { create(:ai_catalog_agent_version, item: agent, version: '1.0.0') }
  let_it_be(:agent_v1_1) { create(:ai_catalog_agent_version, item: agent, version: '1.1.0') }

  let(:params) do
    {
      item: item,
      name: 'New name',
      description: 'New description',
      public: true,
      release: true,
      steps: [{ agent: agent }]
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      {
        steps: [
          {
            agent_id: agent.id,
            current_version_id: agent_v1_1.id,
            pinned_version_prefix: nil
          }.stringify_keys
        ],
        triggers: [1]
      }
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when including a pinned_version_prefix' do
        let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '1.0' }]) }

        it 'sets the correct current_version_id' do
          execute_service

          expect(latest_version.definition['steps'].first).to match a_hash_including(
            'agent_id' => agent.id, 'current_version_id' => agent_v1_0.id, 'pinned_version_prefix' => '1.0'
          )
        end

        context 'when the prefix is not valid' do
          let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '2.2' }]) }

          it_behaves_like 'an error response', 'Step 1: Unable to resolve version with prefix 2.2'
        end
      end

      context 'when flow exceeds maximum steps' do
        before do
          stub_const("Ai::Catalog::Flows::FlowHelper::MAX_STEPS", 1)
        end

        let!(:params) do
          super().merge(steps: [{ agent: agent }, { agent: agent }])
        end

        it_behaves_like 'an error response', Ai::Catalog::Flows::FlowHelper::MAX_STEPS_ERROR
      end

      context 'when user does not have access to read one of the agents' do
        let_it_be(:agent) { create(:ai_catalog_agent, public: false) }

        it_behaves_like 'an error response', 'You have insufficient permissions'
      end

      context 'when flow is not a flow' do
        before do
          allow(item).to receive(:flow?).and_return(false)
        end

        it_behaves_like 'an error response', 'Flow not found'
      end

      context 'when user has access to read one of the agents, but it is private to another project' do
        let_it_be(:other_project) { create(:project, maintainers: user) }
        let_it_be(:agent) { create(:ai_catalog_agent, public: false, project: other_project) }

        it_behaves_like 'an error response', 'Step 1: Agent is private to another project'
      end

      describe 'dependency tracking' do
        let_it_be(:agent2) { create(:ai_catalog_item, :agent, project:) }
        let_it_be(:agent3) { create(:ai_catalog_item, :agent, project:) }
        let_it_be(:agent4) { create(:ai_catalog_item, :agent, project:) }

        let_it_be(:existing_dependency) do
          create(
            :ai_catalog_item_version_dependency, ai_catalog_item_version: item.latest_version, dependency_id: agent.id
          )
        end

        let_it_be(:existing_dependency_no_longer_needed) do
          create(
            :ai_catalog_item_version_dependency, ai_catalog_item_version: item.latest_version, dependency_id: agent2.id
          )
        end

        let(:params) do
          {
            item: item,
            name: 'New name',
            description: 'New description',
            public: true,
            release: true,
            steps: [
              { agent: agent3 },
              { agent: agent }
            ]
          }
        end

        it 'updates the dependencies' do
          execute_service

          expect(latest_version.reload.dependencies.pluck(:dependency_id)).to contain_exactly(agent3.id, agent.id)
        end

        context 'when there are other item versions with dependencies' do
          let_it_be(:other_latest_version_dependency) { create(:ai_catalog_item_version_dependency) }

          it 'does not affect dependencies from other records' do
            expect { execute_service }
              .not_to change { Ai::Catalog::ItemVersionDependency.find(other_latest_version_dependency.id) }
          end
        end

        context 'when saving dependencies fails' do
          before do
            allow(Ai::Catalog::ItemVersionDependency).to receive(:bulk_insert!)
              .and_raise("Dummy error")
          end

          it 'does not update the item' do
            expect { execute_service }
              .to raise_error("Dummy error").and not_change { item.reload.attributes }
          end
        end

        context 'when the flow version is not changing' do
          let(:params) do
            {
              item: item,
              description: 'New description'
            }
          end

          it 'does not update the dependencies' do
            expect(Ai::Catalog::ItemVersionDependency).not_to receive(:bulk_insert!)

            execute_service
          end
        end

        it 'does not cause N+1 queries for each dependency created' do
          # Warmup
          params = { item: item, steps: [{ agent: agent4 }] }
          service = described_class.new(project: project, current_user: user, params: params)
          service.execute

          params = { item: item, steps: [{ agent: agent }] }
          service = described_class.new(project: project, current_user: user, params: params)
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute }

          params = { item: item, steps: [{ agent: agent2 }, { agent: agent3 }] }
          service = described_class.new(project: project, current_user: user, params: params)

          # Ai::Catalog::Flows::FlowHelper#allowed? queries for each agent to check permissions.
          expect { service.execute }.not_to exceed_query_limit(control).with_threshold(1)
        end
      end
    end
  end
end
