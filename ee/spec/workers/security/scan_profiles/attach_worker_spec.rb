# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::AttachWorker, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: group, scan_type: :secret_detection)
  end

  let(:group_id) { group.id }
  let(:scan_profile_id) { scan_profile.id }
  let(:extra_args) { [] }

  subject(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(group_id, scan_profile_id, *extra_args) }

    before do
      allow(Security::ScanProfiles::AttachService).to receive(:execute)
    end

    it 'delegates to the AttachService with default parameters' do
      perform_worker

      expect(Security::ScanProfiles::AttachService)
        .to have_received(:execute).with(group, scan_profile, traverse_hierarchy: true)
    end

    context 'with custom `traverse_hierarchy` parameter' do
      let(:extra_args) { [false] }

      it 'delegates to the AttachService with custom parameters' do
        perform_worker

        expect(Security::ScanProfiles::AttachService)
          .to have_received(:execute).with(group, scan_profile, traverse_hierarchy: false)
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not create any records' do
        perform_worker

        expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
      end
    end

    context 'when scan profile does not exist' do
      let(:scan_profile_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not create any records' do
        perform_worker

        expect(Security::ScanProfiles::AttachService).not_to have_received(:execute)
      end
    end
  end
end
