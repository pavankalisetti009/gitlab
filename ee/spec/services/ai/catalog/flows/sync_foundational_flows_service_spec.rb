# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::SyncFoundationalFlowsService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:flow1) do
    create(:ai_catalog_item, :with_foundational_flow_reference, public: true, organization: group.organization)
  end

  let_it_be(:flow2) do
    create(:ai_catalog_item, :with_foundational_flow_reference, public: true, organization: group.organization)
  end

  let_it_be(:flow3) do
    create(:ai_catalog_item, :with_foundational_flow_reference, public: true, organization: group.organization)
  end

  let(:container) { group }
  let(:current_user) { user }

  subject(:service) { described_class.new(container, current_user: current_user) }

  before do
    allow(Ai::Catalog::Item).to receive(:foundational_flow_ids).and_return([flow1.id, flow2.id, flow3.id])
  end

  describe '#execute' do
    context 'when foundational flows are enabled' do
      context 'when container is a group' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        it 'calls CreateService for each enabled flow' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id, flow2.id])
          allow(Ability).to receive(:allowed?).and_return(true)

          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
          allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

          service.execute

          expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new).twice
        end

        it 'removes consumers not in the enabled list' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          allow(Ability).to receive(:allowed?).and_return(true)

          expect(container).to receive(:remove_foundational_flow_consumers).with([flow2.id, flow3.id])

          service.execute
        end

        it 'handles empty enabled flows list' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([])

          expect(container).to receive(:remove_foundational_flow_consumers).with([flow1.id, flow2.id, flow3.id])

          service.execute
        end
      end

      context 'when container is a project' do
        let(:container) { project }

        before do
          container.project_setting.update!(duo_foundational_flows_enabled: true)
          allow(Ability).to receive(:allowed?).and_return(true)
        end

        it 'creates consumers with parent consumer for flows' do
          parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow1)
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          allow(create_service).to receive(:execute).and_return(ServiceResponse.success)

          expect(Ai::Catalog::ItemConsumers::CreateService).to receive(:new)
            .with(
              container: container,
              current_user: user,
              params: hash_including(item: flow1, parent_item_consumer: parent_consumer)
            ).and_return(create_service)

          service.execute

          expect(create_service).to have_received(:execute)
        end

        it 'skips flows without parent consumers' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

          service.execute
        end
      end

      context 'when user does not have permission' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        let(:unauthorized_user) { create(:user) }
        let(:current_user) { unauthorized_user }

        it 'does not create consumers' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

          service.execute
        end
      end

      context 'when current_user is nil' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        let(:current_user) { nil }

        it 'creates consumers without permission checks' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
          allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

          service.execute

          expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new)
        end
      end

      context 'when catalog item is not found' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        it 'tracks the exception and continues' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999])

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(ActiveRecord::RecordNotFound),
            catalog_item_id: 999,
            container_id: container.id
          )

          expect { service.execute }.not_to raise_error
        end
      end

      context 'when user cannot read catalog item' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
          allow(Ability).to receive(:allowed?).with(user, :admin_ai_catalog_item_consumer, container).and_return(true)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item, flow1).and_return(false)
        end

        it 'does not create consumer' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

          service.execute
        end
      end
    end

    context 'when foundational flows are disabled' do
      before do
        container.namespace_settings.update!(duo_foundational_flows_enabled: false)
      end

      it 'removes all foundational flow consumers' do
        expect(container).to receive(:remove_foundational_flow_consumers).with([flow1.id, flow2.id, flow3.id])

        service.execute
      end

      it 'does not create any consumers' do
        expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

        service.execute
      end
    end
  end

  describe '#foundational_flows_enabled?' do
    context 'when container is a Project' do
      let(:container) { project }

      it 'returns true when duo_foundational_flows_enabled is true' do
        container.project_setting.update!(duo_foundational_flows_enabled: true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end

      it 'returns false when duo_foundational_flows_enabled is false' do
        container.project_setting.update!(duo_foundational_flows_enabled: false)

        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end

      it 'returns nil when project_setting is nil' do
        allow(container).to receive(:project_setting).and_return(nil)

        expect(service.send(:foundational_flows_enabled?)).to be_nil
      end
    end

    context 'when container is a Group' do
      let(:container) { group }

      it 'returns true when duo_foundational_flows_enabled is true' do
        container.namespace_settings.update!(duo_foundational_flows_enabled: true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end

      it 'returns false when duo_foundational_flows_enabled is false' do
        container.namespace_settings.update!(duo_foundational_flows_enabled: false)

        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end

      it 'returns nil when namespace_settings is nil' do
        allow(container).to receive(:namespace_settings).and_return(nil)

        expect(service.send(:foundational_flows_enabled?)).to be_nil
      end
    end

    context 'when container is a Namespace' do
      let(:container) { create(:namespace) }

      it 'checks namespace_settings' do
        allow(container).to receive_message_chain(:namespace_settings, :duo_foundational_flows_enabled).and_return(true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end
    end

    context 'when container is an unsupported type' do
      let(:container) { instance_double(User) }

      it 'returns false' do
        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end
    end
  end

  describe 'integration with CreateService' do
    before do
      container.namespace_settings.update!(duo_foundational_flows_enabled: true)
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
      allow(Ability).to receive(:allowed?).and_return(true)
    end

    it 'calls CreateService with correct parameters' do
      create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
      allow(create_service).to receive(:execute).and_return(ServiceResponse.success)

      expect(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).with(
        container: container,
        current_user: user,
        params: { item: flow1 }
      ).and_return(create_service)

      service.execute
    end
  end

  describe 'error handling' do
    before do
      container.namespace_settings.update!(duo_foundational_flows_enabled: true)
    end

    it 'continues processing after RecordNotFound' do
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999, flow1.id])
      allow(Ai::Catalog::Item).to receive(:find).with(999).and_raise(ActiveRecord::RecordNotFound)
      allow(Ai::Catalog::Item).to receive(:find).with(flow1.id).and_call_original
      allow(Ability).to receive(:allowed?).and_return(true)

      create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
      allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
      allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      service.execute

      expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new).once
    end

    it 'tracks container_id in exception' do
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999])

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        anything,
        hash_including(container_id: container.id)
      )

      service.execute
    end
  end
end
