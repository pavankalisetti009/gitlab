# frozen_string_literal: true

module Search
  module Zoekt
    class DefaultBranchChangedWorker
      include ApplicationWorker
      include Search::Worker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      urgency :low
      idempotent!

      def handle_event(event)
        return unless ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
        return unless ::License.feature_available?(:zoekt_code_search)

        klass = event.data[:container_type].safe_constantize
        return unless klass == Project

        project = klass.find_by_id(event.data[:container_id])
        return unless project&.use_zoekt?

        project.repository.async_update_zoekt_index
      end
    end
  end
end
