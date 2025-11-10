# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::TooManyReplicasEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::TooManyReplicasEvent.new(data: {}) }

  let_it_be(:namespace1) { create(:group) }
  let_it_be(:namespace2) { create(:group) }
  let_it_be(:namespace3) { create(:group) }
  let_it_be(:namespace4) { create(:group) }

  # Has 3 replicas, needs 2 (override) - should delete 1
  let_it_be(:enabled_namespace_with_override) do
    create(:zoekt_enabled_namespace, namespace: namespace1, number_of_replicas_override: 2)
  end

  # Has 4 replicas, needs 2 (default) - should delete 2
  let_it_be(:enabled_namespace_with_default) do
    create(:zoekt_enabled_namespace, namespace: namespace2)
  end

  # Has 2 replicas, needs 2 (default) - should delete 0
  let_it_be(:enabled_namespace_exact) do
    create(:zoekt_enabled_namespace, namespace: namespace3)
  end

  # Has 1 replica, needs 2 (default) - should delete 0
  let_it_be(:enabled_namespace_missing) do
    create(:zoekt_enabled_namespace, namespace: namespace4)
  end

  let_it_be(:replicas_override) do
    create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_with_override)
  end

  let_it_be(:_replicas_default) do
    create_list(:zoekt_replica, 4, zoekt_enabled_namespace: enabled_namespace_with_default)
  end

  let_it_be(:replicas_exact) { create_list(:zoekt_replica, 2, zoekt_enabled_namespace: enabled_namespace_exact) }
  let_it_be(:replicas_missing) { create_list(:zoekt_replica, 1, zoekt_enabled_namespace: enabled_namespace_missing) }

  before do
    stub_const('Search::Zoekt::Settings', Class.new)
    allow(Search::Zoekt::Settings).to receive(:default_number_of_replicas).and_return(2)
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'destroys excess replicas for namespaces with too many replicas' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Replica.count }.by(-3) # 1 from override + 2 from default
    end

    it 'does not destroy replicas for namespaces with exact or missing replicas' do
      consume_event(subscriber: described_class, event: event)

      expect(enabled_namespace_exact.replicas.count).to eq(2)
      expect(enabled_namespace_missing.replicas.count).to eq(1)
    end

    it 'logs the count of replicas destroyed' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:log_extra_metadata_on_done).with(:replicas_destroyed_count, 3)
      end

      consume_event(subscriber: described_class, event: event)
    end

    it 'destroys the correct number of replicas for each namespace' do
      consume_event(subscriber: described_class, event: event)

      expect(enabled_namespace_with_override.replicas.count).to eq(2)
      expect(enabled_namespace_with_default.replicas.count).to eq(2)
    end

    it 'deletes replicas prioritizing by state then by oldest ID' do
      # Get the IDs of replicas before deletion, ordered by state asc, id desc
      override_replica_ids = enabled_namespace_with_override.replicas.order(state: :asc, id: :desc).pluck(:id)
      default_replica_ids = enabled_namespace_with_default.replicas.order(state: :asc, id: :desc).pluck(:id)

      consume_event(subscriber: described_class, event: event)

      # The replicas kept should be those NOT in the excess list (which are ordered by state asc, id desc)
      # So we keep everything except the first N from that ordering
      expect(enabled_namespace_with_override.replicas.pluck(:id)).to match_array(override_replica_ids.drop(1))

      # The replicas kept should be those NOT in the excess list
      expect(enabled_namespace_with_default.replicas.pluck(:id)).to match_array(default_replica_ids.drop(2))
    end

    context 'when there are more namespaces than the batch size' do
      let_it_be(:namespace5) { create(:group) }
      let_it_be(:namespace6) { create(:group) }
      let_it_be(:namespace7) { create(:group) }

      let_it_be(:enabled_namespace_batch1) do
        create(:zoekt_enabled_namespace, namespace: namespace5)
      end

      let_it_be(:enabled_namespace_batch2) do
        create(:zoekt_enabled_namespace, namespace: namespace6)
      end

      let_it_be(:enabled_namespace_batch3) do
        create(:zoekt_enabled_namespace, namespace: namespace7)
      end

      let_it_be(:_replicas_batch1) { create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_batch1) }
      let_it_be(:_replicas_batch2) { create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_batch2) }
      let_it_be(:_replicas_batch3) { create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_batch3) }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'processes only up to the batch size' do
        initial_count = Search::Zoekt::Replica.count

        consume_event(subscriber: described_class, event: event)

        # Should process batch of 2 namespaces with too many replicas
        # Each has 3 replicas and needs 2, so 2 replicas deleted total
        expect(Search::Zoekt::Replica.count).to be < initial_count
      end

      it 'schedules another event when there are more namespaces to process' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to publish_event(Search::Zoekt::TooManyReplicasEvent).with({})
      end

      it 'does not schedule another event when all namespaces are processed' do
        # Process all namespaces
        consume_event(subscriber: described_class, event: event)
        consume_event(subscriber: described_class, event: event)

        # Should not publish another event
        expect { consume_event(subscriber: described_class, event: event) }
         .to not_publish_event(Search::Zoekt::TooManyReplicasEvent)
      end
    end

    context 'when a namespace has no excess replicas after calculation' do
      let_it_be(:namespace8) { create(:group) }
      let_it_be(:enabled_namespace_edge_case) do
        create(:zoekt_enabled_namespace, namespace: namespace8, number_of_replicas_override: 5)
      end

      let_it_be(:_replicas_edge_case) do
        create_list(:zoekt_replica, 5, zoekt_enabled_namespace: enabled_namespace_edge_case)
      end

      it 'does not attempt to destroy any replicas' do
        expect { consume_event(subscriber: described_class, event: event) }
          .not_to change { enabled_namespace_edge_case.replicas.count }
      end
    end

    context 'when there are no namespaces with too many replicas' do
      before_all do
        # Delete all replicas that would trigger the scope
        Search::Zoekt::Replica.for_namespace([namespace1.id, namespace2.id]).delete_all
      end

      it 'does not destroy any replicas' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Replica.count }
      end

      it 'logs zero replicas destroyed' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:replicas_destroyed_count, 0)
        end

        consume_event(subscriber: described_class, event: event)
      end

      it 'does not schedule another event' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to not_publish_event(Search::Zoekt::TooManyReplicasEvent)
      end
    end
  end

  describe 'N+1 queries', :request_store do
    it 'does not create N+1 queries when processing multiple namespaces with replicas' do
      # Create a baseline with 1 namespace
      namespace_a = create(:group)
      enabled_namespace_a = create(:zoekt_enabled_namespace, namespace: namespace_a, number_of_replicas_override: 1)
      create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_a)

      control = ActiveRecord::QueryRecorder.new do
        consume_event(subscriber: described_class, event: event)
      end

      # Add more namespaces with replicas
      namespace_b = create(:group)
      namespace_c = create(:group)
      enabled_namespace_b = create(:zoekt_enabled_namespace, namespace: namespace_b, number_of_replicas_override: 1)
      enabled_namespace_c = create(:zoekt_enabled_namespace, namespace: namespace_c, number_of_replicas_override: 1)
      create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_b)
      create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_c)

      expect do
        consume_event(subscriber: described_class, event: event)
      end.not_to exceed_query_limit(control)
    end
  end
end
