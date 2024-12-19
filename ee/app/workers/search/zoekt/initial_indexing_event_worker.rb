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

        ::Namespace.by_root_id(namespace.id).project_namespaces.each_batch do |project_namespaces_batch|
          project_ids = ::Project.by_project_namespace(project_namespaces_batch.select(:id)).pluck_primary_key
          data = project_ids.map { |p_id| { zoekt_index_id: index.id, project_id: p_id, project_identifier: p_id } }
          Repository.insert_all(data)
        end
        index.initializing!
      end
    end
  end
end
