# frozen_string_literal: true

module Search
  module Zoekt
    class DeleteProjectEventWorker
      include ApplicationWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      feature_category :global_search
      urgency :low
      idempotent!

      def handle_event(event)
        Search::Zoekt.delete_async(event.data[:project_id], root_namespace_id: event.data[:root_namespace_id])
      end
    end
  end
end
