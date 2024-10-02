# frozen_string_literal: true

module Search
  module Zoekt
    class Index < ApplicationRecord
      self.table_name = 'zoekt_indices'
      include EachBatch
      include NamespaceValidateable
      include Gitlab::Loggable

      WATERMARKED_STATES = %i[low_watermark_exceeded high_watermark_exceeded].freeze
      SEARCHEABLE_STATES = %i[ready].freeze
      STORAGE_LOW_WATERMARK = 0.7
      STORAGE_HIGH_WATERMARK = 0.85

      belongs_to :zoekt_enabled_namespace, inverse_of: :indices, class_name: '::Search::Zoekt::EnabledNamespace'
      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :indices, class_name: '::Search::Zoekt::Node'
      belongs_to :replica, foreign_key: :zoekt_replica_id, inverse_of: :indices

      has_many :zoekt_repositories, foreign_key: :zoekt_index_id, inverse_of: :zoekt_index,
        class_name: '::Search::Zoekt::Repository'

      after_commit :index, on: :create
      after_commit :delete_from_index, on: :destroy

      enum state: {
        pending: 0,
        in_progress: 1,
        initializing: 2,
        ready: 10,
        reallocating: 20,
        orphaned: 230,
        pending_deletion: 240
      }

      enum watermark_level: {
        healthy: 0,
        low_watermark_exceeded: 30,
        high_watermark_exceeded: 60,
        critical_watermark_exceeded: 90
      }

      scope :for_node, ->(node) do
        where(node: node)
      end

      scope :for_root_namespace_id, ->(root_namespace_id) do
        where(namespace_id: root_namespace_id).where.not(zoekt_enabled_namespace_id: nil)
      end

      scope :searchable, -> do
        where(state: SEARCHEABLE_STATES)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :for_root_namespace_id_with_search_enabled, ->(root_namespace_id) do
        for_root_namespace_id(root_namespace_id)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :with_all_repositories_ready, -> do
        where_not_exists(Repository.non_ready.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
          .where_exists(Repository.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
      end

      scope :preload_zoekt_enabled_namespace_and_namespace, -> { includes(zoekt_enabled_namespace: :namespace) }
      scope :preload_node, -> { includes(:node) }

      scope :should_be_marked_as_orphaned, -> do
        where(zoekt_enabled_namespace: nil).or(where(replica: nil)).where.not(state: %i[orphaned pending_deletion])
      end

      scope :should_be_deleted, -> do
        where(state: [:orphaned, :pending_deletion])
      end

      scope :should_have_low_watermark, -> do
        where.not(watermark_level: WATERMARKED_STATES).with_storage_over_percent(STORAGE_LOW_WATERMARK)
      end

      scope :should_have_high_watermark, -> do
        where.not(watermark_level: :high_watermark_exceeded).with_storage_over_percent(STORAGE_HIGH_WATERMARK)
      end

      scope :with_storage_over_percent, ->(percent) do
        where('reserved_storage_bytes > 0')
          .where('(used_storage_bytes / reserved_storage_bytes::double precision) >= ?', percent)
      end

      scope :should_have_low_watermark, -> do
        where.not(watermark_level: WATERMARKED_STATES).with_storage_over_percent(STORAGE_LOW_WATERMARK)
      end

      scope :should_have_high_watermark, -> do
        where.not(watermark_level: :high_watermark_exceeded).with_storage_over_percent(STORAGE_HIGH_WATERMARK)
      end

      scope :with_storage_over_percent, ->(percent) do
        where.not(reserved_storage_bytes: [0, nil])
          .where('(used_storage_bytes / reserved_storage_bytes::double precision) >= ?', percent)
      end

      def update_used_storage_bytes!
        update!(used_storage_bytes: zoekt_repositories.sum(:size_bytes))

      rescue StandardError => err
        logger.error(build_structured_payload(
          message: 'Error attempting to update used_storage_bytes',
          index_id: id,
          error: err.message
        ))

        raise err
      end

      def free_storage_bytes
        reserved_storage_bytes.to_i - used_storage_bytes
      end

      private

      def index
        return if Feature.enabled?(:zoekt_initial_indexing_task, Feature.current_request)

        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(zoekt_enabled_namespace.root_namespace_id, :index)
      end

      def delete_from_index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(namespace_id, :delete, zoekt_node_id)
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
