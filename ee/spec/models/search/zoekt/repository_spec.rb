# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Repository, feature_category: :global_search do
  subject { create(:zoekt_repository) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_index).inverse_of(:zoekt_repositories) }
    it { is_expected.to belong_to(:project).inverse_of(:zoekt_repositories) }
  end

  describe 'before_validation' do
    let_it_be(:zoekt_repo) { create(:zoekt_repository) }

    it 'sets project_identifier equal to project_id' do
      zoekt_repo.project_identifier = nil
      expect { zoekt_repo.valid? }.to change { zoekt_repo.project_identifier }.from(nil).to(zoekt_repo.project_id)
    end
  end

  describe 'validation' do
    let_it_be_with_reload(:zoekt_repo) { create(:zoekt_repository) }
    let(:zoekt_index) { zoekt_repo.zoekt_index }
    let(:project) { zoekt_repo.project }

    it 'validates project_id and project_identifier' do
      expect { zoekt_repo.project_id = nil }.not_to change { zoekt_repo.valid? }
      expect { zoekt_repo.project_id = zoekt_repo.project_identifier.next }.to change { zoekt_repo.valid? }.to false
    end

    it 'validated uniqueness on zoekt_index_id and project_identifier' do
      expect(zoekt_repo).to be_valid
      zoekt_repo2 = build(:zoekt_repository, project: nil, project_identifier: project.id, zoekt_index: zoekt_index)
      expect(zoekt_repo2).to be_invalid
    end
  end

  describe 'scope' do
    describe '.uncompleted' do
      let_it_be(:zoekt_repository) { create(:zoekt_repository, state: :pending) }

      it 'returns non ready records' do
        create(:zoekt_repository, state: :ready)
        create(:zoekt_repository, state: :failed)
        expect(described_class.uncompleted).to contain_exactly zoekt_repository
      end
    end

    describe '.pending_or_initializing' do
      let_it_be(:pending_repo) { create(:zoekt_repository, state: :pending) }
      let_it_be(:pending_repo2) { create(:zoekt_repository, state: :pending) }
      let_it_be(:initializing_repo) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:initializing_repo2) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:ready_repo) { create(:zoekt_repository, state: :ready) }
      let_it_be(:failed_repo) { create(:zoekt_repository, state: :failed) }

      subject(:collection) { described_class.pending_or_initializing }

      it 'returns only pending or initializing records' do
        expect(collection).to include pending_repo, pending_repo2, initializing_repo, initializing_repo2
        expect(collection).not_to include ready_repo, failed_repo
      end
    end

    describe '.for_zoekt_indices' do
      let_it_be(:zoekt_index) { create(:zoekt_index) }
      let_it_be(:zoekt_index2) { create(:zoekt_index) }
      let_it_be(:zoekt_index3) { create(:zoekt_index) }
      let_it_be(:zoekt_repository) { create(:zoekt_repository, zoekt_index: zoekt_index) }
      let_it_be(:zoekt_repository2) { create(:zoekt_repository, zoekt_index: zoekt_index) }
      let_it_be(:zoekt_repository3) { create(:zoekt_repository, zoekt_index: zoekt_index2) }

      it 'returns records for matching zoekt indices' do
        create(:zoekt_repository, zoekt_index: zoekt_index3)
        expect(described_class.for_zoekt_indices([zoekt_index, zoekt_index2])).to contain_exactly zoekt_repository,
          zoekt_repository2, zoekt_repository3
      end
    end

    describe '.searchable' do
      let_it_be(:ready) { create(:zoekt_repository, state: :ready) }
      let_it_be(:pending) { create(:zoekt_repository, state: :pending) }
      let_it_be(:initializing) { create(:zoekt_repository, state: :initializing) }
      let_it_be(:orphaned) { create(:zoekt_repository, state: :orphaned) }
      let_it_be(:pending_deletion) { create(:zoekt_repository, state: :pending_deletion) }
      let_it_be(:failed) { create(:zoekt_repository, state: :failed) }

      subject(:records) { described_class.searchable }

      it 'returns all repositories with state includes in SEARCHABLE_STATES' do
        expect(records).to include ready
        expect(records).not_to include pending, initializing, orphaned, pending_deletion, failed
      end
    end
  end

  describe '.create_tasks', :freeze_time do
    let(:task_type) { :index_repo }

    context 'when repository does not exists for a project and zoekt_index' do
      let_it_be(:project) { create(:project) }
      let_it_be(:index) { create(:zoekt_index) }

      it 'creates a new initializing repository and task' do
        perform_at = Time.zone.now
        expect do
          described_class.create_tasks(project_id: project.id, zoekt_index: index, task_type: task_type,
            perform_at: perform_at
          )
        end.to change { described_class.count }.by(1).and change { Search::Zoekt::Task.count }.by(1)
        repo = described_class.last
        expect(repo).to be_initializing
        expect(repo.project).to eq project
        expect(repo.zoekt_index).to eq index
        task = Search::Zoekt::Task.last
        expect(task.zoekt_repository).to eq repo
        expect(task.project_identifier).to eq repo.project_identifier
        expect(task).to be_index_repo
        expect(task.perform_at).to eq perform_at
      end
    end

    context 'when repository already exists for a project and zoekt_index' do
      let_it_be(:repo) { create(:zoekt_repository) }
      let_it_be(:zoekt_index) { repo.zoekt_index }

      it 'creates task' do
        perform_at = Time.zone.now
        expect do
          described_class.create_tasks(project_id: repo.project_identifier, zoekt_index: zoekt_index,
            task_type: task_type, perform_at: perform_at
          )
        end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
        task = Search::Zoekt::Task.last
        expect(task.zoekt_repository).to eq repo
        expect(task.project_identifier).to eq repo.project_identifier
        expect(task).to be_index_repo
        expect(task.perform_at).to eq perform_at
      end

      context 'when project is already deleted' do
        let_it_be(:repo_with_deleted_project) {  create(:zoekt_repository, zoekt_index: zoekt_index) }
        let_it_be(:repo_with_deleted_project2) { create(:zoekt_repository, zoekt_index: zoekt_index) }

        before do
          [repo_with_deleted_project.project, repo_with_deleted_project2.project].map(&:destroy!)
        end

        it 'creates task with the supplied project_id' do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project_id: repo_with_deleted_project2.project_identifier,
              zoekt_index: zoekt_index, task_type: :delete_repo, perform_at: perform_at
            )
          end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
          task = Search::Zoekt::Task.last
          expect(task.zoekt_repository).to eq repo_with_deleted_project2
          expect(task.project_identifier).to eq repo_with_deleted_project2.project_identifier
          expect(task).to be_delete_repo
          expect(task.perform_at).to eq perform_at
        end
      end

      context 'when there is already a pending task with the provided zoekt_node_id and task_type' do
        before do
          create(:zoekt_task, :pending, zoekt_repository: repo, task_type: task_type, node: zoekt_index.node)
        end

        it 'does not create the new task' do
          expect do
            described_class.create_tasks(project_id: repo.project_identifier, zoekt_index: zoekt_index,
              task_type: task_type, perform_at: Time.zone.now
            )
          end.not_to change { Search::Zoekt::Task.count }
        end
      end
    end

    context 'when repository is in failed state' do
      let_it_be(:repo) { create(:zoekt_repository, state: :failed) }
      let_it_be(:zoekt_index) { repo.zoekt_index }

      context 'and task_type is index_repo' do
        let(:task_type) { :index_repo }

        it 'does not creates task' do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project_id: repo.project_identifier, zoekt_index: zoekt_index,
              task_type: task_type, perform_at: perform_at
            )
          end.not_to change { described_class.count }
        end
      end

      context 'and task_type is delete_repo' do
        let(:task_type) { :delete_repo }

        it 'creates task' do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project_id: repo.project_identifier, zoekt_index: zoekt_index,
              task_type: task_type, perform_at: perform_at
            )
          end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
          task = Search::Zoekt::Task.last
          expect(task.zoekt_repository).to eq repo
          expect(task.project_identifier).to eq repo.project_identifier
          expect(task).to be_delete_repo
          expect(task.perform_at).to eq perform_at
        end
      end
    end
  end

  describe '.create_bulk_tasks', :freeze_time do
    let_it_be(:zoekt_repo_with_pending_tasks) { create(:zoekt_repository) }
    let_it_be(:zoekt_repo_with_processing_tasks) { create(:zoekt_repository) }
    let_it_be(:zoekt_repo_without_tasks) { create(:zoekt_repository) }
    let_it_be(:failed_zoekt_repo_without_tasks) { create(:zoekt_repository, :failed) }

    before do
      create(:zoekt_task, :pending, zoekt_repository: zoekt_repo_with_pending_tasks)
      create(:zoekt_task, :pending, task_type: :delete_repo, zoekt_repository: zoekt_repo_with_pending_tasks)
      create(:zoekt_task, :processing, zoekt_repository: zoekt_repo_with_processing_tasks)
      create(:zoekt_task, :processing, task_type: :delete_repo, zoekt_repository: zoekt_repo_with_processing_tasks)
    end

    context 'when task_type is delete_repo' do
      it 'creates zoekt_tasks for failed repos and repos which do not have pending tasks' do
        pending_tasks_count = zoekt_repo_with_pending_tasks.reload.tasks.count
        processing_tasks_count = zoekt_repo_with_processing_tasks.reload.tasks.count
        described_class.create_bulk_tasks(task_type: :delete_repo)
        expect(zoekt_repo_with_pending_tasks.reload.tasks.count).to eq pending_tasks_count
        expect(zoekt_repo_with_processing_tasks.reload.tasks.count).to eq processing_tasks_count + 1
        expect(zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(failed_zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(zoekt_repo_without_tasks).to be_initializing
        expect(zoekt_repo_with_processing_tasks).to be_initializing
        expect(zoekt_repo_with_pending_tasks).to be_pending
      end
    end

    context 'when task_type is index_repo' do
      it 'does not creates tasks for failed repos and creates tasks for repos which do not have pending tasks' do
        pending_tasks_count = zoekt_repo_with_pending_tasks.reload.tasks.count
        processing_tasks_count = zoekt_repo_with_processing_tasks.reload.tasks.count
        described_class.create_bulk_tasks
        expect(zoekt_repo_with_pending_tasks.reload.tasks.count).to eq pending_tasks_count
        expect(zoekt_repo_with_processing_tasks.reload.tasks.count).to eq processing_tasks_count + 1
        expect(zoekt_repo_without_tasks.reload.tasks.count).to eq 1
        expect(failed_zoekt_repo_without_tasks.reload.tasks.count).to eq 0
        expect(zoekt_repo_without_tasks).to be_initializing
        expect(zoekt_repo_with_processing_tasks).to be_initializing
        expect(zoekt_repo_with_pending_tasks).to be_pending
      end
    end
  end
end
