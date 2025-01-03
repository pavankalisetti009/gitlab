# frozen_string_literal: true

module Search
  module Zoekt
    class IndexMarkedAsToDeleteEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      BATCH_SIZE = 5_000

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_indices, :zoekt_repositories], 10.minutes

      def handle_event(event)
        Index.id_in(event.data[:index_ids]).find_each do |idx|
          if idx.zoekt_repositories.exists?
            idx.zoekt_repositories.not_pending_deletion.each_batch(of: BATCH_SIZE) do |batch|
              batch.update_all(state: :pending_deletion)
            end
          else
            idx.destroy
          end
        end
      end
    end
  end
end
