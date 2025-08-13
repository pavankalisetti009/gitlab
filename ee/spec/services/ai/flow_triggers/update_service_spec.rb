# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::UpdateService, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:different_group) { create(:group) }
  let_it_be(:human_user) { create(:user, owner_of: [project.group, different_group]) }
  let_it_be(:service_account_provisioned_by_group) do
    create(:service_account, developer_of: project, provisioned_by_group: project.group)
  end

  let(:current_user) { human_user }
  let(:service_account) { service_account_provisioned_by_group }

  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) { { user_id: service_account.id, event_types: event_types } }
  let(:trigger) { create(:ai_flow_trigger, project: project, user: service_account) }
  let(:service) { described_class.new(project: project, current_user: current_user, trigger: trigger) }

  before do
    stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
    stub_licensed_features(service_accounts: true)
  end

  describe '#execute' do
    it 'updates a flow trigger' do
      response = service.execute(params)
      expect(response).to be_success
      flow_trigger = response.payload

      expect(flow_trigger).to be_persisted
      expect(flow_trigger.user).to eq(service_account)
      expect(flow_trigger.event_types).to contain_exactly(Ai::FlowTrigger::EVENT_TYPES[:mention])
      expect(flow_trigger.project).to eq(project)
    end

    context 'with invalid params' do
      let(:event_types) { [99] }

      it 'returns the error' do
        response = service.execute(params)
        expect(response).not_to be_success
        expect(response.message).to include('invalid event types: 99')
      end
    end

    context 'when the current_user is not an owner of the provisioning group of the service account' do
      let(:current_user) { create(:user) }

      it 'returns an error and does not create the flow trigger' do
        response = service.execute(params)
        expect(response).not_to be_success
      end
    end

    context 'when the provisioning group is not the root ancestor of the project' do
      let(:service_account) { create(:service_account, developer_of: project, provisioned_by_group: different_group) }

      it 'returns an error and does not create the flow trigger' do
        response = service.execute(params)
        expect(response).not_to be_success
      end
    end
  end
end
