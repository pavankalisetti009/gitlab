# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::CleanOldNamespaceConnectionsService, feature_category: :security_asset_inventories do
  describe '.execute' do
    let(:group_id) { 123 }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_class_method) { described_class.execute(group_id) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object with group_id and calls execute', :aggregate_failures do
      execute_class_method

      expect(described_class).to have_received(:new).with(group_id)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:other_root_namespace) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_namespace) }
    let_it_be(:subgroup) { create(:group, parent: group) }

    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group) }
    let_it_be(:project3) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project, group: other_root_namespace) }

    let_it_be(:scan_profile_in_root) { create(:security_scan_profile, namespace: root_namespace) }
    let_it_be(:scan_profile_in_other_root) { create(:security_scan_profile, namespace: other_root_namespace) }

    let(:group_id) { group.id }
    let(:service) { described_class.new(group_id) }

    subject(:execute) { service.execute }

    context 'when group exists' do
      let!(:connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)
      end

      let!(:connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project2)
      end

      let!(:connection3) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project3)
      end

      let!(:connection_in_same_root) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project1)
      end

      let!(:other_connection) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: other_project)
      end

      it 'deletes project connections to profiles not in the same root namespace' do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-3)

        expect(Security::ScanProfileProject.exists?(connection1.id)).to be(false)
        expect(Security::ScanProfileProject.exists?(connection2.id)).to be(false)
        expect(Security::ScanProfileProject.exists?(connection3.id)).to be(false)
      end

      it 'keeps connections within for profiles within same root namespace' do
        execute

        expect(Security::ScanProfileProject.exists?(connection_in_same_root.id)).to be(true)
      end

      it 'keeps connections for projects outside the group' do
        execute

        expect(Security::ScanProfileProject.exists?(other_connection.id)).to be(true)
      end
    end

    context 'when group projects has no connections to profiles outside root namespace' do
      let!(:connection_in_same_root) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project1)
      end

      it 'does not delete any connections' do
        expect { execute }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when group does not exist' do
      where(:group_id) { [nil, non_existing_record_id] }

      with_them do
        it 'does not delete any connections' do
          create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: project1)

          expect { execute }.not_to change { Security::ScanProfileProject.count }
        end
      end
    end

    context 'when processing projects in batches' do
      let_it_be(:batch_test_group) { create(:group, parent: root_namespace) }
      let_it_be(:batch_project1) { create(:project, group: batch_test_group) }
      let_it_be(:batch_project2) { create(:project, group: batch_test_group) }

      let(:group_id) { batch_test_group.id }

      let!(:batch_connection1) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: batch_project1)
      end

      let!(:batch_connection2) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other_root, project: batch_project2)
      end

      before do
        stub_const("#{described_class}::PROJECT_BATCH_SIZE", 1)
      end

      it 'deletes project connections to profiles not in the same root namespace' do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-2)
      end

      it 'processes projects in batches' do
        relation = Security::ScanProfileProject.all
        allow(Security::ScanProfileProject).to receive_message_chain(:by_project_id,
          :not_in_root_namespace).and_return(relation)
        allow(relation).to receive(:delete_all)

        execute

        expect(relation).to have_received(:delete_all).twice
      end
    end
  end
end
