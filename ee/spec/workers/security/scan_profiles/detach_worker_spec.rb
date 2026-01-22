# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::DetachWorker, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: group, scan_type: :secret_detection)
  end

  let(:group_id) { group.id }
  let(:scan_profile_id) { scan_profile.id }
  let(:current_user_id) { user.id }
  let(:extra_args) { [] }

  subject(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform_worker) { worker.perform(group_id, scan_profile_id, current_user_id, *extra_args) }

    before do
      allow(Security::ScanProfiles::DetachService).to receive(:execute)
    end

    it 'delegates to the DetachService with default parameters' do
      perform_worker

      expect(Security::ScanProfiles::DetachService)
        .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: true)
    end

    context 'with custom `traverse_hierarchy` parameter' do
      let(:extra_args) { [false] }

      it 'delegates to the DetachService with custom parameters' do
        perform_worker

        expect(Security::ScanProfiles::DetachService)
          .to have_received(:execute).with(group, scan_profile, current_user: user, traverse_hierarchy: false)
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::DetachService).not_to have_received(:execute)
      end
    end

    context 'when scan profile does not exist' do
      let(:scan_profile_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::DetachService).not_to have_received(:execute)
      end
    end

    context 'when current user does not exist' do
      let(:current_user_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(Security::ScanProfiles::DetachService).not_to have_received(:execute)
      end
    end
  end
end
