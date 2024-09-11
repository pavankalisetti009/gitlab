# frozen_string_literal: true

module Search
  module Zoekt
    class IndexMarkedAsToDeleteEventWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      BATCH_SIZE = 10_000

      feature_category :global_search
      idempotent!

      def handle_event(event)
        Index.where(id: event.data[:index_ids]).find_each do |idx| # rubocop:disable CodeReuse/ActiveRecord -- Not relevant
          if idx.zoekt_repositories.exists?
            idx.zoekt_repositories.each_batch(of: BATCH_SIZE) do |batch|
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
