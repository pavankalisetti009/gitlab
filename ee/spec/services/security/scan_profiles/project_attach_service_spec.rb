# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProjectAttachService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: root_group) }
  let_it_be(:project_at_limit) { create(:project, namespace: root_group) }
  let_it_be(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Test Profile')
  end

  let_it_be(:other_profile) { create(:security_scan_profile, namespace: root_group, scan_type: :sast) }
  let_it_be(:at_limit_association) do
    create(:security_scan_profile_project, project: project_at_limit, scan_profile: other_profile)
  end

  before do
    stub_const('Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT', 1)
  end

  shared_examples 'returns empty errors' do
    it 'returns empty errors' do
      result = execute_service

      expect(result[:errors]).to be_empty
    end
  end

  describe '.execute' do
    subject(:execute_service) do
      described_class.execute(profile: profile, projects: projects)
    end

    context 'when no projects are provided' do
      let(:projects) { [] }

      it 'returns an error' do
        result = execute_service

        expect(result[:errors]).to include('At least one project must be provided')
      end

      it 'does not create any associations' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end
    end

    context 'when projects are provided' do
      let(:projects) { [project1, project2] }

      it 'creates associations for all projects' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(projects.count)
      end

      it 'creates correct associations' do
        execute_service

        expect(Security::ScanProfileProject.where(project: project1, scan_profile: profile)).to exist
        expect(Security::ScanProfileProject.where(project: project2, scan_profile: profile)).to exist
      end

      it_behaves_like 'returns empty errors'
    end

    context 'when a project has reached the profile limit' do
      let(:projects) { [project1, project_at_limit] }

      it 'only attaches to the project under the limit' do
        expect { execute_service }.to change { Security::ScanProfileProject.count }.by(1)
        expect(Security::ScanProfileProject.where(project: project1, scan_profile: profile)).to exist
        expect(Security::ScanProfileProject.where(project: project_at_limit, scan_profile: profile)).not_to exist
      end

      it 'returns an error for the project at limit' do
        result = execute_service
        expect(result[:errors]).to include(
          "Project #{project_at_limit.id} has reached the maximum limit of scan profiles."
        )
      end
    end

    context 'when profile is already attached to a project' do
      let(:projects) { [project1] }

      before do
        create(:security_scan_profile_project, scan_profile: profile, project: project1)
      end

      it 'does not create duplicate associations' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end

      it_behaves_like 'returns empty errors'
    end

    context 'when a project is at the limit and has the specific profile attached already' do
      let(:projects) { [project_at_limit] }

      before do
        create(:security_scan_profile_project, project: project_at_limit, scan_profile: profile)
      end

      it 'does not create a duplicate' do
        expect { execute_service }.not_to change { Security::ScanProfileProject.count }
      end

      it_behaves_like 'returns empty errors'
    end

    context 'when more than MAX_PROJECTS are provided' do
      let(:projects) { [project1, project2, project_at_limit] }

      before do
        stub_const("#{described_class}::MAX_PROJECTS", 2)
      end

      it 'returns an error' do
        result = execute_service
        expect(result[:errors]).to include('Cannot attach profile to more than 2 items at once.')
      end
    end

    context 'when an unexpected error occurs during insertion' do
      let(:projects) { [project1] }

      before do
        allow(Security::ScanProfileProject).to receive(:connection).and_raise(StandardError, 'DB connection failed')
      end

      it 'returns the error message' do
        result = execute_service

        expect(result[:errors]).to eq(['DB connection failed'])
      end
    end
  end
end
