# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::AttachWorker, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }

  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: subgroup) }
  let_it_be(:project3) { create(:project, namespace: nested_subgroup) }

  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection)
  end

  let(:group) { root_group }
  let(:group_id) { group.id }
  let(:scan_profile_id) { scan_profile.id }
  let(:traverse_hierarchy) { true }
  let(:retry_count) { 0 }

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'delegates to the AttachService with default parameters' do
      expect_next_instance_of(
        Security::ScanProfiles::AttachService, group, scan_profile, traverse_hierarchy: true, retry_count: 0
      ) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      worker.perform(group_id, scan_profile_id)
    end

    it 'delegates to the AttachService with custom parameters' do
      expect_next_instance_of(
        Security::ScanProfiles::AttachService, group, scan_profile, traverse_hierarchy: false, retry_count: 5
      ) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      worker.perform(group_id, scan_profile_id, false, 5)
    end

    it 'attaches the scan profile to all projects in the group hierarchy' do
      expect { worker.perform(group_id, scan_profile_id) }
        .to change { Security::ScanProfileProject.count }.by(3)

      expect(Security::ScanProfileProject.exists?(project: project1, security_scan_profile_id: scan_profile.id))
        .to be(true)
      expect(Security::ScanProfileProject.exists?(project: project2, security_scan_profile_id: scan_profile.id))
        .to be(true)
      expect(Security::ScanProfileProject.exists?(project: project3, security_scan_profile_id: scan_profile.id))
        .to be(true)
    end

    context 'when traverse_hierarchy is false' do
      it 'only attaches the scan profile to projects in the specified group' do
        expect { worker.perform(group_id, scan_profile_id, false) }
          .to change { Security::ScanProfileProject.count }.by(1)

        expect(Security::ScanProfileProject.exists?(project: project1, security_scan_profile_id: scan_profile.id))
          .to be(true)
        expect(Security::ScanProfileProject.exists?(project: project2, security_scan_profile_id: scan_profile.id))
          .to be(false)
        expect(Security::ScanProfileProject.exists?(project: project3, security_scan_profile_id: scan_profile.id))
          .to be(false)
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { worker.perform(group_id, scan_profile_id) }.not_to raise_error
      end

      it 'does not create any records' do
        expect { worker.perform(group_id, scan_profile_id) }
          .not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when scan profile does not exist' do
      let(:scan_profile_id) { non_existing_record_id }

      it 'exits gracefully without raising an error' do
        expect { worker.perform(group_id, scan_profile_id) }.not_to raise_error
      end

      it 'does not create any records' do
        expect { worker.perform(group_id, scan_profile_id) }
          .not_to change { Security::ScanProfileProject.count }
      end
    end
  end
end
