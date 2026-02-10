# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::CreateService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:different_group) { create(:group) }
  let_it_be(:human_user) { create(:user, maintainer_of: project) }
  let_it_be(:composite_identity_enforced) { false }
  let_it_be(:service_account_provisioned_by_group) do
    create(:service_account, developer_of: project, provisioned_by_group: project.group,
      composite_identity_enforced: composite_identity_enforced)
  end

  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:current_user) { human_user }
  let(:service_account) { service_account_provisioned_by_group }

  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) do
    { user_id: service_account.id, event_types: event_types, config_path: ".gitlab/duo/flow.yml",
      description: "some flow" }
  end

  let(:service) { described_class.new(project: project, current_user: current_user) }

  before do
    stub_ee_application_setting(duo_features_enabled: true)
    allow(Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    ::Ai::Setting.instance.update!(duo_core_features_enabled: true)
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

    context 'when ai_catalog_create_third_party_flows is disabled' do
      before do
        stub_feature_flags(ai_catalog_create_third_party_flows: false)
      end

      it 'returns an error' do
        response = service.execute(params)

        expect(response).to be_error
        expect(response.message).to include('You have insufficient permissions')
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

    context 'when the current_user is not a maintainer of the project' do
      let(:current_user) { create(:user, developer_of: project) }

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

      let(:item_consumer_id) { item_consumer.id }

      let(:catalog_params) do
        {
          user_id: service_account.id,
          event_types: event_types,
          description: "catalog flow trigger",
          ai_catalog_item_consumer_id: item_consumer_id
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

      context 'when ai_catalog_create_third_party_flows is disabled' do
        before do
          stub_feature_flags(ai_catalog_create_third_party_flows: false)
        end

        it 'creates a flow trigger with catalog item' do
          response = service.execute(catalog_params)
          expect(response).to be_success
          flow_trigger = response.payload

          expect(flow_trigger).to be_persisted
          expect(flow_trigger.ai_catalog_item_consumer).to eq(item_consumer)
          expect(flow_trigger.config_path).to be_nil
        end

        context 'when creating a trigger for a third party flow' do
          let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, :for_third_party_flow, project: project) }

          it 'returns an error' do
            response = service.execute(catalog_params)

            expect(response).to be_error
            expect(response.message).to include('You have insufficient permissions')
          end
        end

        context 'when the item consumer does not exist' do
          let(:item_consumer_id) { non_existing_record_id }

          it 'returns an error' do
            response = service.execute(catalog_params)
            expect(response).to be_error
            expect(response.message).to include("Ai catalog item consumer can't be blank")
          end
        end

        context 'when the item consumer is nil' do
          let(:item_consumer_id) { nil }

          it 'returns an error' do
            response = service.execute(catalog_params)
            expect(response).to be_error
            expect(response.message).to include("Ai catalog item consumer can't be blank")
          end
        end
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
