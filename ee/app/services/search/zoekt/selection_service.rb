# frozen_string_literal: true

module Search
  module Zoekt
    class SelectionService
      attr_reader :max_batch_size

      ResourcePool = Struct.new(:enabled_namespaces, :nodes)

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      def initialize(max_batch_size: 128)
        @max_batch_size = max_batch_size
      end

      def execute
        namespaces = fetch_enabled_namespace_for_indexing
        nodes = fetch_available_nodes

        ResourcePool.new(namespaces, nodes)
      end

      private

      def fetch_enabled_namespace_for_indexing(project_count_limit: 20_000)
        [].tap do |batch|
          ::Search::Zoekt::EnabledNamespace.with_missing_indices.find_each do |ns|
            next unless ns.metadata['last_rollout_failed_at'].nil?
            next if ::Namespace.by_root_id(ns.root_namespace_id).project_namespaces.count > project_count_limit

            batch << ns
            break if batch.count >= max_batch_size
          end
        end
      end

      def fetch_available_nodes
        ::Search::Zoekt::Node.with_positive_unclaimed_storage_bytes.online
      end
    end
  end
end
