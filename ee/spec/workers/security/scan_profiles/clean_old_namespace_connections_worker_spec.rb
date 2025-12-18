# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::CleanOldNamespaceConnectionsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }
  let_it_be(:group) { create(:group) }
  let(:group_id) { group.id }
  let(:delete_service) { Security::ScanProfiles::CleanOldNamespaceConnectionsService }

  subject(:perform) { worker.perform(group_id) }

  before do
    allow(delete_service).to receive(:execute)
  end

  describe '#perform' do
    context 'when group_id is provided' do
      it 'calls DeleteGroupConnectionsService with the group_id' do
        perform

        expect(delete_service).to have_received(:execute).with(group_id)
      end
    end

    context 'when group_id is nil' do
      let(:group_id) { nil }

      it 'does not call DeleteGroupConnectionsService' do
        perform

        expect(delete_service).not_to have_received(:execute)
      end
    end
  end
end
