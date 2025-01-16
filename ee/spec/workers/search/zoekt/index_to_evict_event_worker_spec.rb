# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexToEvictEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexToEvictEvent.new(data: {}) }

  let_it_be(:healthy_index) { create(:zoekt_index, watermark_level: :healthy) }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when no indices are returned by critical_watermark_exceeded scope' do
      it 'does nothing' do
        expect { consume_event(subscriber: described_class, event: event) }.not_to change {
          ::Search::Zoekt::Replica.count
        }
      end
    end

    context 'when indices are returned by critical_watermark_exceeded scope' do
      let_it_be(:indices) { create_list(:zoekt_index, 3, watermark_level: :critical_watermark_exceeded) }

      it 'deletes associated replicas and logs metadata with deleted count' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:replicas_deleted_count, 3)
        end

        expect { consume_event(subscriber: described_class, event: event) }.to change {
          ::Search::Zoekt::Replica.count
        }.by(-3)
      end

      it 'processes in batches' do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:replicas_deleted_count, 2)
        end

        expect { consume_event(subscriber: described_class, event: event) }.to change {
          ::Search::Zoekt::Replica.count
        }.by(-2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:replicas_deleted_count, 1)
        end

        expect { consume_event(subscriber: described_class, event: event) }.to change {
          ::Search::Zoekt::Replica.count
        }.by(-1)
      end
    end
  end
end
