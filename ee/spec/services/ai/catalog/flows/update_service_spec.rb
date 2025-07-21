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

    shared_examples 'does not update the flow' do
      it 'does not update the flow' do
        expect { execute_service }.not_to change { flow.reload.attributes }
      end
    end

    shared_examples 'returns error response' do |error:|
      specify do
        result = execute_service

        expect(result).to be_error
        expect(result.message).to contain_exactly(error)
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'does not update the flow'
      it_behaves_like 'returns error response', error: 'You have insufficient permissions'
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

      it 'returns success response' do
        expect(execute_service).to be_success
      end

      context 'when updated flow is invalid' do
        let(:params) do
          {
            flow: flow,
            name: ''
          }
        end

        it_behaves_like 'does not update the flow'
        it_behaves_like 'returns error response', error: "Name can't be blank"
      end

      context 'when flow is not a flow' do
        before do
          allow(flow).to receive(:flow?).and_return(false)
        end

        it_behaves_like 'does not update the flow'
        it_behaves_like 'returns error response', error: 'Flow not found'
      end
    end
  end
end
