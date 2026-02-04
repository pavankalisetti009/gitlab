# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::RepositoryManager, feature_category: :duo_chat do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:repository_url) { 'https://github.com/example/repo.git' }
  let(:repo_path) { 'example/repo' }

  describe '.clone_repository' do
    subject(:clone_repository) do
      described_class.clone_repository(repository_url, repo_path, group, user)
    end

    context 'when cloning a repository for a new project' do
      it 'creates a new project' do
        project = create(:project, namespace: group, name: 'repo')
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(project)
        end

        allow(described_class).to receive(:wait_for_repository_import).and_return(true)

        result = clone_repository

        expect(result).to eq(project)
      end

      it 'calls wait_for_repository_import' do
        project = create(:project, namespace: group, name: 'repo')
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(project)
        end

        expect(described_class).to receive(:wait_for_repository_import).with(project).and_return(true)

        clone_repository
      end
    end

    context 'when cloning a repository for an existing project' do
      it 'deletes the existing project before creating a new one' do
        # Create an existing project that will be found
        existing_project = create(:project, namespace: group, name: 'repo')

        # Create a new project that will be returned by CreateService
        new_project = create(:project, namespace: group, name: 'repo2')

        # Mock Project.find_by_full_path to return the existing project
        allow(Project).to receive(:find_by_full_path).and_return(existing_project)

        allow_next_instance_of(::Projects::MarkForDeletionService) do |service|
          allow(service).to receive(:execute)
        end

        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(new_project)
        end

        allow(described_class).to receive(:wait_for_repository_import).and_return(true)
        allow(Gitlab::Duo::Developments::SweBenchSeeder::IssueManager).to receive(:delete_all_issues)

        clone_repository

        # Verify that delete_all_issues was called
        expect(Gitlab::Duo::Developments::SweBenchSeeder::IssueManager).to have_received(:delete_all_issues)
      end
    end

    context 'when project creation encounters errors' do
      it 'returns nil when the project has validation errors' do
        # rubocop:disable RSpec/VerifiedDoubles -- errors object doesn't match exact interface
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(
            double(errors: double(any?: true, full_messages: ['Error message']))
          )
        end
        # rubocop:enable RSpec/VerifiedDoubles

        expect { clone_repository }.to output(/Failed to create project: Error message/).to_stdout
      end

      it 'returns nil when the project is not persisted to the database' do
        # rubocop:disable RSpec/VerifiedDoubles -- errors object doesn't match exact interface
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(
            double(errors: double(any?: false), persisted?: false)
          )
        end
        # rubocop:enable RSpec/VerifiedDoubles

        expect { clone_repository }.to output(/Failed to create project: Project was not saved/).to_stdout
      end
    end

    context 'when an unexpected error occurs during cloning' do
      it 'returns nil and logs the error message' do
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_raise(StandardError, 'Test error')
        end

        result = clone_repository

        expect(result).to be_nil
      end
    end
  end

  describe '.wait_for_repository_import' do
    let(:project) { create(:project, namespace: group) }

    subject(:wait_for_import) do
      described_class.wait_for_repository_import(project, max_wait_seconds: 5)
    end

    context 'when the repository import completes successfully' do
      it 'returns true when the repository exists' do
        allow(project).to receive(:reset)
        allow(project).to receive(:repository_exists?).and_return(true)

        result = wait_for_import

        expect(result).to be true
      end
    end

    context 'when the repository import fails' do
      it 'returns false when the import state indicates failure' do
        import_state = instance_double(ProjectImportState, status: 'failed', failed?: true, finished?: false,
          last_error: 'Import failed')
        allow(project).to receive(:reset)
        allow(project).to receive_messages(import_state: import_state, repository_exists?: false)

        result = wait_for_import

        expect(result).to be false
      end
    end

    context 'when the repository import finishes with success status' do
      it 'returns true when the import state is finished' do
        import_state = instance_double(ProjectImportState, status: 'finished', failed?: false, finished?: true)
        allow(project).to receive(:reset)
        allow(project).to receive_messages(import_state: import_state, repository_exists?: false)

        result = wait_for_import

        expect(result).to be true
      end
    end

    context 'when the import exceeds the maximum wait time' do
      it 'returns false when the timeout is exceeded' do
        import_state = instance_double(ProjectImportState, status: 'started', failed?: false, finished?: false)
        allow(project).to receive(:reset)
        allow(project).to receive_messages(import_state: import_state, repository_exists?: false)

        result = wait_for_import

        expect(result).to be false
      end
    end

    context 'when an unexpected error occurs during import waiting' do
      it 'returns false and logs the error message' do
        allow(project).to receive(:reset).and_raise(StandardError, 'Test error')

        result = wait_for_import

        expect(result).to be false
      end
    end
  end
end
