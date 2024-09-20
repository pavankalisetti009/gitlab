# frozen_string_literal: true

module Search
  module Zoekt
    class InitialIndexingEventWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      idempotent!

      def handle_event(event)
        index = Index.find_by_id(event.data[:index_id])
        return if index.nil? || !index.pending?

        namespace = ::Namespace.find_by_id(index.namespace_id)
        return if namespace.nil?

        namespace.all_project_ids.find_each { |project| IndexingTaskService.execute(project.id, :index_repo) }
        index.initializing!
      end
    end
  end
end
