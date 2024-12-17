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
        index = find_index(event.data[:index_id])
        return if index.nil? || !index.pending?

        namespace = find_namespace(index.namespace_id)
        return if namespace.nil?

        create_repositories(index, namespace)
        index.initializing!
      end

      private

      def find_index(index_id)
        Index.find_by_id(index_id)
      end

      def find_namespace(namespace_id)
        ::Namespace.find_by_id(namespace_id)
      end

      def create_repositories(index, namespace)
        if index.metadata['project_id_from'].blank?
          create_repositories_for_namespace(index, namespace)
        else
          create_repositories_for_project_range(index)
        end
      end

      def create_repositories_for_namespace(index, namespace)
        ::Namespace.by_root_id(namespace.id).project_namespaces.each_batch do |project_namespaces_batch|
          project_ids = fetch_project_ids(project_namespaces_batch)
          insert_repositories!(index, project_ids)
        end
      end

      def create_repositories_for_project_range(index)
        project_ids = determine_project_id_range(index)
        ::Project.id_in(project_ids).each_batch do |batch|
          project_ids = batch.pluck_primary_key
          insert_repositories!(index, project_ids)
        end
      end

      def fetch_project_ids(project_namespaces_batch)
        ::Project.by_project_namespace(project_namespaces_batch.select(:id)).pluck_primary_key
      end

      def determine_project_id_range(index)
        return (index.metadata['project_id_from']..) if index.metadata['project_id_to'].blank?

        index.metadata['project_id_from']..index.metadata['project_id_to']
      end

      def insert_repositories!(index, project_ids)
        data = project_ids.map do |p_id|
          { zoekt_index_id: index.id, project_id: p_id, project_identifier: p_id }
        end
        Repository.insert_all(data)
      end
    end
  end
end
