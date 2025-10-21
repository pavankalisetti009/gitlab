# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::CreateService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:different_group) { create(:group) }
  let_it_be(:human_user) { create(:user, owner_of: [project.group, different_group]) }
  let_it_be(:composite_identity_enforced) { false }
  let_it_be(:service_account_provisioned_by_group) do
    create(:service_account, developer_of: project, provisioned_by_group: project.group,
      composite_identity_enforced: composite_identity_enforced)
  end

  let(:current_user) { human_user }
  let(:service_account) { service_account_provisioned_by_group }

  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) do
    { user_id: service_account.id, event_types: event_types, config_path: ".gitlab/duo/flow.yml",
      description: "some flow" }
  end

  let(:service) { described_class.new(project: project, current_user: current_user) }

  before do
    stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
    stub_licensed_features(service_accounts: true)
  end

  describe '#execute' do
    it 'creates a flow trigger' do
      response = service.execute(params)
      expect(response).to be_success
      flow_trigger = response.payload

      expect(flow_trigger).to be_persisted
      expect(flow_trigger.user).to eq(service_account)
      expect(flow_trigger.event_types).to contain_exactly(Ai::FlowTrigger::EVENT_TYPES[:mention])
      expect(flow_trigger.project).to eq(project)
      expect(service_account.reload.composite_identity_enforced).to be(true)
    end

    context 'when ai_flow_triggers_use_composite_identity is disabled' do
      let_it_be(:composite_identity_enforced) { false }

      before do
        stub_feature_flags(ai_flow_triggers_use_composite_identity: false)
      end

      it 'does not update composite_identity_enforced field' do
        response = service.execute(params)
        expect(response).to be_success

        expect(service_account.reload.composite_identity_enforced).to be(false)
      end
    end

    context 'when using invalid params' do
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

    context 'when using catalog item configuration' do
      let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, :for_flow, project: project) }

      let(:catalog_params) do
        {
          user_id: service_account.id,
          event_types: event_types,
          description: "catalog flow trigger",
          ai_catalog_item_consumer_id: item_consumer.id
        }
      end

      it 'creates a flow trigger with catalog item' do
        response = service.execute(catalog_params)
        expect(response).to be_success
        flow_trigger = response.payload

        expect(flow_trigger).to be_persisted
        expect(flow_trigger.ai_catalog_item_consumer).to eq(item_consumer)
        expect(flow_trigger.config_path).to be_nil
      end
    end

    context 'with invalid catalog item parameters' do
      let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, project: create(:project)) }

      let(:catalog_params) do
        {
          user_id: service_account.id,
          event_types: event_types,
          description: "catalog flow trigger",
          ai_catalog_item_consumer_id: item_consumer.id
        }
      end

      it 'returns an error' do
        response = service.execute(catalog_params)
        expect(response).to be_error
        expect(response.message).to include('ai_catalog_item_consumer project does not match project')
      end
    end
  end
end
