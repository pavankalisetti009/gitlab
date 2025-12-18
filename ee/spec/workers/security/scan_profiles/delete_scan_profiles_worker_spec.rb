# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::DeleteScanProfilesWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:scan_profile1) { create(:security_scan_profile, namespace: namespace, name: "profile_1") }
    let_it_be(:scan_profile2) { create(:security_scan_profile, namespace: namespace, name: "profile_2") }
    let_it_be(:scan_profile3) { create(:security_scan_profile, namespace: namespace, name: "profile_3") }

    let(:scan_profile_ids) { [scan_profile1.id, scan_profile2.id, scan_profile3.id] }
    let(:delete_service) { Security::ScanProfiles::DeleteScanProfileService }

    subject(:perform) { worker.perform(scan_profile_ids) }

    before do
      allow(delete_service).to receive(:execute)
    end

    context 'when scan_profile_ids is not empty' do
      it 'calls DeleteScanProfileService for each scan profile id' do
        perform

        expect(delete_service).to have_received(:execute).with(scan_profile1.id)
        expect(delete_service).to have_received(:execute).with(scan_profile2.id)
        expect(delete_service).to have_received(:execute).with(scan_profile3.id)
      end
    end
  end
end
