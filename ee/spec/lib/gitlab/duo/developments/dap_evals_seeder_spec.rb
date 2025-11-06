# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::DapEvalsSeeder, feature_category: :"self-hosted_models" do
  let_it_be(:group) { create(:group, path: 'gitlab-duo') }
  let_it_be(:source_project) { create(:project, :repository, namespace: group, path: 'test') }
  let_it_be(:user) { create(:user, username: 'root') }

  describe '.seed_issues' do
    let(:output_file) { 'test_output.yml' }
    let_it_be(:cloned_project) { create(:project, :repository, namespace: group, path: 'test-issue-to-mr-eval') }

    before do
      allow(described_class).to receive_messages(find_project: source_project, find_root_user: user,
        clone_project: cloned_project)
      allow(described_class).to receive(:save_issue_urls_to_yaml)
    end

    subject(:seed_issues) { described_class.seed_issues(output_file: output_file) }

    context 'when no issues exist' do
      it 'creates all issues' do
        expect(described_class).to receive(:create_issue).exactly(6).times.and_return(
          create(:issue, project: cloned_project)
        )

        expect { seed_issues }.to output(/Created 6 issues, skipped 0 existing issues/).to_stdout
      end

      it 'saves issue URLs to YAML file' do
        allow(described_class).to receive(:create_issue).and_return(
          create(:issue, project: cloned_project)
        )

        expect(described_class).to receive(:save_issue_urls_to_yaml).with(
          array_including(String), output_file
        )

        seed_issues
      end
    end

    context 'when some issues already exist' do
      before do
        # Create an existing issue with the same title as the first issue in ISSUES_TO_CREATE
        create(:issue, project: cloned_project, title: 'Rename MyHandler to MyCustomHandler')
      end

      it 'skips existing issues and creates only new ones' do
        expect(described_class).to receive(:create_issue).exactly(5).times.and_return(
          create(:issue, project: cloned_project)
        )

        expect { seed_issues }.to output(
          a_string_including(
            "Issue 'Rename MyHandler to MyCustomHandler' already exists in " \
              "#{cloned_project.full_path}. Skipping creation."
          ).and(a_string_including("Created 5 issues, skipped 1 existing issues"))
        ).to_stdout
      end

      it 'does not save URLs for skipped issues to YAML file' do
        allow(described_class).to receive(:create_issue).and_return(
          create(:issue, project: cloned_project)
        )

        # Should only save URLs for the 5 newly created issues, not the skipped one
        expect(described_class).to receive(:save_issue_urls_to_yaml).with(
          array_including(String), output_file
        )

        seed_issues
      end
    end

    context 'when an error occurs during seeding' do
      before do
        allow(described_class).to receive(:find_project).and_raise(StandardError, 'Database connection failed')
      end

      it 'outputs error message and re-raises the exception' do
        expect { seed_issues }.to output(/Error seeding DAP evaluation issues: Database connection failed/).to_stdout
          .and raise_error(StandardError, 'Database connection failed')
      end
    end
  end

  describe '.find_project' do
    subject(:find_project) { described_class.find_project }

    context 'when project exists' do
      it 'returns the project' do
        expect(find_project).to eq(source_project)
      end
    end

    context 'when project does not exist' do
      before do
        source_project.destroy!
      end

      it 'raises an error with setup instructions' do
        expect { find_project }.to raise_error(RuntimeError, %r{Project 'gitlab-duo/test' not found})
      end
    end
  end

  describe '.find_root_user' do
    subject(:find_root_user) { described_class.find_root_user }

    context 'when root user exists' do
      it 'returns the root user' do
        expect(find_root_user).to eq(user)
      end
    end

    context 'when root user does not exist' do
      before do
        user.destroy!
      end

      it 'raises an error' do
        expect { find_root_user }.to raise_error(RuntimeError, /Root user not found/)
      end
    end
  end

  describe '.clone_project' do
    let_it_be(:test_source_project) { create(:project, :repository) }
    let_it_be(:test_user) { create(:user) }
    let(:fork_service) { instance_double(Projects::ForkService) }
    let(:mark_for_deletion_service) { instance_double(Projects::MarkForDeletionService) }
    let_it_be(:cloned_project) { create(:project, namespace: group, path: 'test-issue-to-mr-eval') }
    let(:service_result) { ServiceResponse.success(payload: { project: cloned_project }) }

    subject(:clone_project) { described_class.clone_project(test_source_project, test_user) }

    before do
      allow(Projects::ForkService).to receive(:new).and_return(fork_service)
      allow(fork_service).to receive(:execute).and_return(service_result)
    end

    context 'when group exists and no existing project' do
      it 'successfully forks the project' do
        expect(Projects::ForkService).to receive(:new).with(
          test_source_project,
          test_user,
          hash_including(
            namespace: group,
            name: 'test-issue-to-mr-eval',
            path: 'test-issue-to-mr-eval'
          )
        )

        expect(clone_project).to eq(cloned_project)
      end
    end

    context 'when group does not exist' do
      let_it_be(:different_group) { create(:group, path: 'different-group') }

      before do
        stub_const('Gitlab::Duo::Developments::DapEvalsSeeder::GROUP_PATH', 'nonexistent-group')
      end

      it 'raises an error' do
        expect { clone_project }.to raise_error(RuntimeError, /Group 'nonexistent-group' not found/)
      end
    end

    context 'when fork service fails' do
      let(:service_result) { ServiceResponse.error(message: 'Fork failed') }

      it 'raises an error' do
        expect { clone_project }.to raise_error(RuntimeError, /Failed to fork project: Fork failed/)
      end
    end
  end

  describe '.issue_already_exists?' do
    let_it_be(:project) { create(:project) }
    let(:title) { 'Test Issue' }

    subject(:issue_exists) { described_class.issue_already_exists?(project, title) }

    context 'when issue exists' do
      before do
        create(:issue, project: project, title: title)
      end

      it 'returns true' do
        expect(issue_exists).to be true
      end
    end

    context 'when issue does not exist' do
      it 'returns false' do
        expect(issue_exists).to be false
      end
    end
  end

  describe '.create_issue' do
    let_it_be(:project) { create(:project) }
    let(:issue_data) { { title: 'Test Issue', description: 'Test description' } }
    let(:create_service) { instance_double(Issues::CreateService) }
    let(:issue) { create(:issue, project: project) }
    let(:service_result) { ServiceResponse.success(payload: { issue: issue }) }

    subject(:create_issue) { described_class.create_issue(project, user, issue_data) }

    before do
      allow(Issues::CreateService).to receive(:new).and_return(create_service)
      allow(create_service).to receive(:execute).and_return(service_result)
    end

    context 'when issue creation succeeds' do
      it 'returns the created issue' do
        expect(create_issue).to eq(issue)
      end

      it 'calls the service with correct parameters' do
        expect(Issues::CreateService).to receive(:new).with(
          container: project,
          current_user: user,
          params: {
            title: 'Test Issue',
            description: 'Test description'
          }
        )

        create_issue
      end
    end
  end

  describe '.delete_all_issues' do
    let_it_be(:project) { create(:project) }
    let!(:issue1) { create(:issue, project: project, title: 'Issue 1') }
    let!(:issue2) { create(:issue, project: project, title: 'Issue 2') }
    let(:destroy_service) { instance_double(Issues::DestroyService) }

    subject(:delete_all_issues) { described_class.delete_all_issues(project, user) }

    before do
      allow(Issues::DestroyService).to receive(:new).and_return(destroy_service)
      allow(destroy_service).to receive(:execute)
    end

    it 'deletes all issues' do
      expect(Issues::DestroyService).to receive(:new).with(
        container: project,
        current_user: user
      ).twice

      expect(destroy_service).to receive(:execute).with(issue1)
      expect(destroy_service).to receive(:execute).with(issue2)

      expect { delete_all_issues }.to output(/Deleted 2 issues/).to_stdout
    end

    context 'when deletion fails for an issue' do
      before do
        allow(destroy_service).to receive(:execute).with(issue1).and_raise(StandardError, 'Deletion failed')
        allow(destroy_service).to receive(:execute).with(issue2)
      end

      it 'continues with other issues and reports the error' do
        expect { delete_all_issues }.to output(/Failed to delete issue 'Issue 1': Deletion failed/).to_stdout
      end
    end
  end

  describe '.save_issue_urls_to_yaml' do
    let(:issue_urls) { ['http://example.com/issue1', 'http://example.com/issue2'] }
    let(:output_file) { 'test_output.yml' }
    let(:expected_data) { { "issues" => issue_urls } }

    subject(:save_to_yaml) { described_class.save_issue_urls_to_yaml(issue_urls, output_file) }

    before do
      allow(File).to receive(:write)
    end

    context 'with valid output file' do
      it 'writes YAML data to file' do
        expect(File).to receive(:write).with(output_file, expected_data.to_yaml)

        save_to_yaml
      end
    end

    context 'when file write fails' do
      before do
        allow(File).to receive(:write).and_raise(StandardError, 'Write failed')
      end

      it 'handles the error gracefully' do
        expect { save_to_yaml }.to output(/Warning: Failed to save issue URLs to YAML file: Write failed/).to_stdout
      end
    end
  end
end
