# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProjectDetachService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: root_group) }
  let_it_be(:project3) { create(:project, namespace: root_group) }
  let_it_be(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection)
  end

  let_it_be(:other_profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :sast, name: 'Other Profile')
  end

  describe '.execute' do
    subject(:result) { described_class.execute(profile: profile, projects: projects) }

    context 'when projects is empty' do
      let(:projects) { [] }

      it 'returns an error' do
        expect(result[:errors]).to include('At least one project must be provided')
      end
    end

    context 'when too many projects are provided' do
      let(:projects) { [project1, project2] }

      before do
        stub_const("#{described_class}::MAX_PROJECTS", 1)
      end

      it 'returns an error' do
        expect(result[:errors]).to include(
          "Cannot detach profile from more than #{described_class::MAX_PROJECTS} items at once."
        )
      end
    end

    context 'when projects have the profile attached' do
      let(:projects) { [project1, project2] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
        create(:security_scan_profile_project, scan_profile: profile, project: project2)
      end

      it 'detaches the profile from all projects' do
        expect { result }.to change { Security::ScanProfileProject.count }.by(-2)

        expect(result[:errors]).to be_empty
        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
        expect(Security::ScanProfileProject.by_project_id(project2).for_scan_profile(profile)).not_to exist
      end
    end

    context 'when some projects do not have the profile attached' do
      let(:projects) { [project1, project2] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
      end

      it 'detaches only from projects that have the profile' do
        expect { result }.to change { Security::ScanProfileProject.count }.by(-1)

        expect(result[:errors]).to be_empty
        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
      end
    end

    context 'when no projects have the profile attached' do
      let(:projects) { [project1, project2] }

      it 'succeeds without errors' do
        expect { result }.not_to change { Security::ScanProfileProject.count }

        expect(result[:errors]).to be_empty
      end
    end

    context 'when projects have other profiles attached' do
      let(:projects) { [project1] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
        create(:security_scan_profile_project, scan_profile: other_profile, project: project1)
      end

      it 'only detaches the specified profile' do
        expect { result }.to change { Security::ScanProfileProject.count }.by(-1)

        expect(result[:errors]).to be_empty
        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
        expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(other_profile)).to exist
      end
    end

    context 'when an error occurs' do
      let(:projects) { [project1] }

      before do
        allow(Security::ScanProfileProject).to receive(:by_project_id).and_raise(StandardError, 'Database error')
      end

      it 'returns the error message' do
        expect(result[:errors]).to include('Database error')
      end
    end
  end
end
