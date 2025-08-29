# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToReindexEventWorker, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node, schema_version: 2) }
  let_it_be(:index) { create(:zoekt_index, node: node) }

  let(:event) { Search::Zoekt::RepoToReindexEvent.new(data: {}) }
  let(:node_scoped_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: node.id }) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when zoekt is disabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
      end

      it 'does not create any reindexing tasks' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when event has no zoekt_node_id' do
      it 'does not process any repositories' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      context 'with repositories needing reindexing within batch size' do
        it 'creates reindexing tasks for repositories with schema version mismatch without re-emitting event' do
          batch_size = 2
          test_node = create(:zoekt_node, schema_version: 2)
          test_index = create(:zoekt_index, node: test_node)
          test_event = Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id })

          # Create repositories with different schema version than the node
          create_list(:zoekt_repository, batch_size, zoekt_index: test_index, schema_version: 1, state: :ready)
          stub_const("#{described_class}::LIMIT", batch_size)

          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: test_event)
          end.to change { Search::Zoekt::Task.count }.from(0).to(batch_size)
        end
      end

      context 'with more repositories than batch size needing reindexing' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          stub_const("#{described_class}::LIMIT", 2)
          # Create 5 repositories with different schema version than the node
          create_list(:zoekt_repository, 5, zoekt_index: test_index, schema_version: 1, state: :ready)
        end

        it 'processes batch size without scheduling another event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: test_event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end

      context 'when repositories have pending or processing tasks' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          stub_const("#{described_class}::LIMIT", 3)
        end

        context 'when some repositories have pending tasks and others do not' do
          before do
            # Create repository with pending task (should be skipped)
            repository_with_task = create(:zoekt_repository, zoekt_index: test_index, schema_version: 1, state: :ready)
            create(:zoekt_task, zoekt_repository: repository_with_task, state: :pending)

            # Create repositories without tasks (should be processed)
            create_list(:zoekt_repository, 2, zoekt_index: test_index, schema_version: 1, state: :ready)
          end

          it 'creates tasks only for repositories without pending tasks, respecting available slots' do
            expect do
              consume_event(subscriber: described_class, event: test_event)
            end.to change { Search::Zoekt::Task.count }.by(2) # 3 total slots - 1 existing task = 2 new tasks
          end
        end

        context 'when all available slots are filled with existing tasks' do
          before do
            repositories = create_list(:zoekt_repository, 3, zoekt_index: test_index, schema_version: 1, state: :ready)
            repositories.each do |repo|
              create(:zoekt_task, zoekt_repository: repo, state: :pending)
            end
          end

          it 'does not create any new tasks when all slots are filled' do
            expect do
              consume_event(subscriber: described_class, event: test_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end
      end

      context 'when no repositories need reindexing' do
        before do
          node = create(:zoekt_node, schema_version: 1)
          index = create(:zoekt_index, node: node)

          # Create repositories with same schema version as the node (no reindexing needed)
          create_list(:zoekt_repository, 3, zoekt_index: index, schema_version: 1, state: :ready)
        end

        it 'does not create any tasks and does not re-emit event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: event)
          end.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'when all reindexing is completed' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          # Create repositories that need reindexing but have no pending/processing tasks
          create_list(:zoekt_repository, 2, zoekt_index: test_index, schema_version: 1, state: :ready)
          stub_const("#{described_class}::LIMIT", 5)
        end

        it 'processes tasks without re-emitting event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: test_event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end

      context 'when repositories have matching schema versions' do
        before do
          node = create(:zoekt_node, schema_version: 1)
          index = create(:zoekt_index, node: node)

          # Create repositories with same schema version as node (no reindexing needed)
          create_list(:zoekt_repository, 2, zoekt_index: index, schema_version: 1, state: :ready)
        end

        it 'does not create any tasks' do
          expect do
            consume_event(subscriber: described_class, event: event)
          end.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'with node-scoped events' do
        let_it_be(:node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:other_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:index) { create(:zoekt_index, node: node) }
        let_it_be(:other_index) { create(:zoekt_index, node: other_node) }

        before do
          stub_const("#{described_class}::LIMIT", 5)
        end

        context 'when processing repositories for a specific node' do
          before do
            # Create repositories needing reindexing on both nodes
            create_list(:zoekt_repository, 2, zoekt_index: index, schema_version: 1, state: :ready)
            create_list(:zoekt_repository, 3, zoekt_index: other_index, schema_version: 1, state: :ready)
          end

          it 'only processes repositories for the specified node' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.to change { Search::Zoekt::Task.count }.by(2)

            # Verify tasks were created only for the specified node's repositories
            created_tasks = Search::Zoekt::Task.all
            expect(created_tasks.map(&:zoekt_node_id).uniq).to eq([node.id])
          end
        end

        context 'when specified node has repositories with pending tasks' do
          before do
            # Create repository with pending task (should be skipped)
            repository = create(:zoekt_repository, zoekt_index: index, schema_version: 1, state: :ready)
            create(:zoekt_task, zoekt_repository: repository, state: :pending)

            # Create additional repository without task (should be processed)
            create(:zoekt_repository, zoekt_index: index, schema_version: 1, state: :ready)

            # Create repositories on other node that could be processed
            create_list(:zoekt_repository, 2, zoekt_index: other_index, schema_version: 1, state: :ready)
          end

          it 'processes available repositories for the specified node, respecting available slots' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.to change {
                     Search::Zoekt::Task.count
                   }.by(1) # 5 total slots - 1 existing task = 4 available, but only 1 repo without task
          end
        end

        context 'when specified node has no repositories needing reindexing' do
          before do
            # Create repositories with matching schema versions on the specified node
            create_list(:zoekt_repository, 2, zoekt_index: index, schema_version: 2, state: :ready)

            # Create repositories needing reindexing on other node
            create_list(:zoekt_repository, 3, zoekt_index: other_index, schema_version: 1, state: :ready)
          end

          it 'does not create any tasks' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end

        context 'when node ID does not exist' do
          let(:invalid_node_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: 99999 }) }

          before do
            create_list(:zoekt_repository, 2, zoekt_index: index, schema_version: 1, state: :ready)
          end

          it 'does not create any tasks' do
            expect do
              consume_event(subscriber: described_class, event: invalid_node_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end
      end
    end
  end
end
