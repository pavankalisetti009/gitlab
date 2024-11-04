# frozen_string_literal: true

module Search
  module Zoekt
    class InitialIndexingEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      idempotent!

      # Create the pending zoekt_repositories and move the index to initializing
      def handle_event(event)
        index = Index.find_by_id(event.data[:index_id])
        return if index.nil? || !index.pending?

        namespace = ::Namespace.find_by_id(index.namespace_id)
        return if namespace.nil?

        namespace.all_project_ids.each_batch do |batch|
          data = batch.map { |p| { zoekt_index_id: index.id, project_id: p.id, project_identifier: p.id } }
          Repository.insert_all(data)
        end
        index.initializing!
      end
    end
  end
end
