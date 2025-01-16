# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NodeWithNegativeUnclaimedStorageEventWorker, :zoekt_settings_enabled,
  feature_category: :global_search do
  let(:event) { Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent.new(data: data) }

  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:index) { create(:zoekt_index, node: node) }
  let_it_be(:negative_node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:negative_index) do
    create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
  end

  let(:data) do
    { node_ids: [node.id, negative_node.id] }
  end

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when node_ids is empty in the event data' do
      let(:data) do
        { node_ids: [] }
      end

      it 'does nothing' do
        expect(Search::Zoekt::Node).not_to receive(:negative_unclaimed_storage_bytes)

        expect { consume_event(subscriber: described_class, event: event) }
          .not_to publish_event(Search::Zoekt::IndexToEvictEvent)
      end
    end

    it 'processes nodes with negative unclaimed storage bytes' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
      end

      expect { consume_event(subscriber: described_class, event: event) }
        .to change { negative_index.reload.watermark_level }.from('healthy').to('critical_watermark_exceeded')
        .and not_change { index.reload.watermark_level }
        .and publish_event(Search::Zoekt::IndexToEvictEvent).with({})
    end

    it 'processes in batches' do
      idx_2 = create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
      idx_3 = create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)

      stub_const("#{described_class}::BATCH_SIZE", 2)

      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 2)
      end

      expect { consume_event(subscriber: described_class, event: event) }
        .to change { negative_index.reload.watermark_level }.from('healthy').to('critical_watermark_exceeded')
        .and change { idx_2.reload.watermark_level }.from('healthy').to('critical_watermark_exceeded')
        .and not_change { idx_3.reload.watermark_level }
        .and not_change { index.reload.watermark_level }
        .and publish_event(Search::Zoekt::IndexToEvictEvent).with({})

      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
      end

      expect { consume_event(subscriber: described_class, event: event) }
        .to change { idx_3.reload.watermark_level }.from('healthy').to('critical_watermark_exceeded')
        .and publish_event(Search::Zoekt::IndexToEvictEvent).with({})
    end
  end
end
