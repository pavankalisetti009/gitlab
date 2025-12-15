# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:seed_service) { instance_double(Ai::Catalog::Flows::SeedFoundationalFlowsService) }
    let(:sync_service) { instance_double(Ai::Catalog::Flows::SyncFoundationalFlowsService) }

    before do
      allow(Ai::Catalog::Flows::SeedFoundationalFlowsService).to receive(:new).and_return(seed_service)
      allow(seed_service).to receive(:execute)

      allow(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new).and_return(sync_service)
      allow(sync_service).to receive(:execute)
    end

    it 'calls SeedFoundationalFlowsService for the organization' do
      expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
        .to receive(:new).with(current_user: user, organization: group.organization)
                         .and_return(seed_service)
      expect(seed_service).to receive(:execute)

      worker.perform(group.id, user.id)
    end

    it 'calls SyncFoundationalFlowsService for the group' do
      expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
        .to receive(:new).with(group, current_user: user)
                         .and_return(sync_service)
      expect(sync_service).to receive(:execute)

      worker.perform(group.id, user.id)
    end

    it 'calls SyncFoundationalFlowsService for all projects in the group hierarchy' do
      expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
        .to receive(:new).with(project, current_user: user)
                         .and_return(sync_service)
      expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
        .to receive(:new).with(subgroup_project, current_user: user)
                         .and_return(sync_service)

      worker.perform(group.id, user.id)
    end

    context 'when user_id is not provided' do
      it 'passes nil as current_user to the services' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
          .to receive(:new).with(current_user: nil, organization: group.organization)
                           .and_return(seed_service)

        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .to receive(:new).with(group, current_user: nil)
                           .and_return(sync_service)

        worker.perform(group.id, nil)
      end
    end

    context 'when user does not exist' do
      it 'passes nil as current_user to the services' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
          .to receive(:new).with(current_user: nil, organization: group.organization)
                           .and_return(seed_service)

        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .to receive(:new).with(group, current_user: nil)
                           .and_return(sync_service)

        worker.perform(group.id, non_existing_record_id)
      end
    end

    context 'when group does not exist' do
      it 'does not call any service' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService).not_to receive(:new)
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).not_to receive(:new)

        worker.perform(non_existing_record_id, user.id)
      end
    end

    context 'when group has no organization' do
      let(:group_without_org) { create(:group) }

      before do
        allow(group_without_org).to receive(:organization).and_return(nil)
        allow(Group).to receive(:find_by_id).with(group_without_org.id).and_return(group_without_org)
      end

      it 'does not call SeedFoundationalFlowsService but continues with sync operations' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService).not_to receive(:new)
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new).at_least(:once)
                                                                                 .and_return(sync_service)

        worker.perform(group_without_org.id, user.id)
      end
    end
  end

  describe 'worker attributes' do
    it 'has the correct feature category' do
      expect(described_class.get_feature_category).to eq(:ai_abstraction_layer)
    end

    it 'has the correct urgency' do
      expect(described_class.get_urgency).to eq(:low)
    end

    it 'is idempotent' do
      expect(described_class.idempotent?).to be(true)
    end

    it 'has external dependencies' do
      expect(described_class.worker_has_external_dependencies?).to be(true)
    end
  end
end
