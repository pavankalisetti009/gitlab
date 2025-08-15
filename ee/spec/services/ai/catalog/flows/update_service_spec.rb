# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_item, :with_version, item_type: :flow, project: project) }
  let_it_be_with_reload(:latest_version) { create(:ai_catalog_flow_version, version: '1.1.0', item: flow) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:v1_0) { create(:ai_catalog_agent_version, item: agent, version: '1.0.0') }
  let_it_be(:v1_1) { create(:ai_catalog_agent_version, item: agent, version: '1.1.0') }

  let(:params) do
    {
      flow: flow,
      name: 'New name',
      description: 'New description',
      public: true,
      steps: [{ agent: agent }]
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    shared_examples 'an error response' do |errors|
      it 'returns an error response' do
        result = execute_service

        expect(result).to be_error
        expect(result.message).to match_array(Array(errors))
        expect(result.payload[:flow]).to eq(flow)
      end

      it 'does not update the flow' do
        expect { execute_service }.not_to change { flow.reload.attributes }
      end

      it 'does not update the latest version' do
        expect { execute_service }.not_to change { latest_version.reload.attributes }
      end

      it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
          .not_to trigger_internal_events('update_ai_catalog_item')
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      it 'updates the flow and its latest version' do
        execute_service

        expect(flow.reload).to have_attributes(
          name: 'New name',
          description: 'New description',
          public: true
        )
        expect(latest_version.reload).to have_attributes(
          schema_version: 1,
          version: '1.1.0',
          definition: {
            steps: [
              {
                agent_id: agent.id, current_version_id: v1_1.id, pinned_version_prefix: nil
              }.stringify_keys
            ],
            triggers: [1]
          }.stringify_keys
        )
      end

      context 'when including a pinned_version_prefix' do
        let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '1.0' }]) }

        it 'sets the correct current_version_id' do
          execute_service

          expect(latest_version.definition['steps'].first).to match a_hash_including(
            'agent_id' => agent.id, 'current_version_id' => v1_0.id, 'pinned_version_prefix' => '1.0'
          )
        end

        context 'when the prefix is not valid' do
          let(:params) { super().merge(steps: [{ agent: agent, pinned_version_prefix: '2' }]) }

          it_behaves_like 'an error response', 'Step 1: Unable to resolve version with prefix 2'
        end
      end

      context 'when flow exceeds maximum steps' do
        before do
          stub_const("Ai::Catalog::Flows::FlowHelper::MAX_STEPS", 1)
        end

        let!(:params) do
          super().merge(steps: [{ agent: agent }, { agent: agent }])
        end

        it_behaves_like 'an error response', 'Maximum steps for a flow (1) exceeded'
      end

      it 'returns success response with flow in payload' do
        result = execute_service

        expect(result).to be_success
        expect(result[:flow]).to eq(flow)
      end

      it 'trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
         .to trigger_internal_events('update_ai_catalog_item')
         .with(user: user, project: project, additional_properties: { label: 'flow' })
      end

      context 'when updated flow is invalid' do
        let(:params) do
          {
            flow: flow,
            name: ''
          }
        end

        it_behaves_like 'an error response', "Name can't be blank"
      end

      context 'when flow is not a flow' do
        before do
          allow(flow).to receive(:flow?).and_return(false)
        end

        it_behaves_like 'an error response', 'Flow not found'
      end
    end
  end
end
