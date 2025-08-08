# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToReindexEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoToReindexEvent.new(data: {}) }

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

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      context 'with repositories needing reindexing within batch size' do
        it 'creates reindexing tasks for repositories with schema version mismatch without re-emitting event' do
          batch_size = 2
          node = create(:zoekt_node, schema_version: 2)
          index = create(:zoekt_index, node: node)

          # Create repositories with different schema version than the node
          create_list(:zoekt_repository, batch_size, zoekt_index: index, schema_version: 1, state: :ready)
          stub_const("#{described_class}::BATCH_SIZE", batch_size)

          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: event)
          end.to change { Search::Zoekt::Task.count }.from(0).to(batch_size)
        end
      end

      context 'with more repositories than batch size needing reindexing' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
          node = create(:zoekt_node, schema_version: 2)
          index = create(:zoekt_index, node: node)

          # Create 5 repositories with different schema version than the node
          create_list(:zoekt_repository, 5, zoekt_index: index, schema_version: 1, state: :ready)
        end

        it 'processes batch size without scheduling another event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end

      context 'when repositories have pending or processing tasks' do
        before do
          node = create(:zoekt_node, schema_version: 2)
          index = create(:zoekt_index, node: node)
          repository = create(:zoekt_repository, zoekt_index: index, schema_version: 1, state: :ready)

          # Create a pending task for the repository
          create(:zoekt_task, zoekt_repository: repository, state: :pending)
        end

        it 'does not process due to existing pending/processing tasks' do
          expect(Search::Zoekt::Repository).not_to receive(:create_bulk_tasks)

          expect do
            consume_event(subscriber: described_class, event: event)
          end.not_to change { Search::Zoekt::Task.count }
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
        before do
          node = create(:zoekt_node, schema_version: 2)
          index = create(:zoekt_index, node: node)

          # Create repositories that need reindexing but have no pending/processing tasks
          create_list(:zoekt_repository, 2, zoekt_index: index, schema_version: 1, state: :ready)
          stub_const("#{described_class}::BATCH_SIZE", 5)
        end

        it 'processes tasks without re-emitting event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: event) }
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
    end
  end
end
