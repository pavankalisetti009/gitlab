# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_item, :with_version, item_type: :flow, project: project) }

  let(:params) do
    {
      flow: flow,
      name: 'New name',
      description: 'New description',
      public: true
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

      it 'updates the flow' do
        execute_service

        expect(flow.reload).to have_attributes(
          name: 'New name',
          description: 'New description',
          public: true
        )
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
