# frozen_string_literal: true

module Search
  module Zoekt
    class Index < ApplicationRecord
      self.table_name = 'zoekt_indices'
      include EachBatch
      include NamespaceValidateable
      include Gitlab::Loggable

      SEARCHEABLE_STATES = %i[ready].freeze
      SHOULD_BE_DELETED_STATES = %i[orphaned pending_deletion].freeze
      STORAGE_IDEAL_PERCENT_USED = 0.4
      STORAGE_LOW_WATERMARK = 0.7
      STORAGE_HIGH_WATERMARK = 0.85

      belongs_to :zoekt_enabled_namespace, inverse_of: :indices, class_name: '::Search::Zoekt::EnabledNamespace'
      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :indices, class_name: '::Search::Zoekt::Node'
      belongs_to :replica, foreign_key: :zoekt_replica_id, inverse_of: :indices

      has_many :zoekt_repositories, foreign_key: :zoekt_index_id, inverse_of: :zoekt_index,
        class_name: '::Search::Zoekt::Repository'

      validates :metadata, json_schema: { filename: 'zoekt_indices_metadata' }

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
        overprovisioned: 10,
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

      scope :pre_ready, -> { where(state: %i[pending in_progress initializing]) }

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

      scope :with_all_finished_repositories, -> do
        where_not_exists(Repository.uncompleted.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
      end

      scope :preload_zoekt_enabled_namespace_and_namespace, -> { includes(zoekt_enabled_namespace: :namespace) }
      scope :preload_node, -> { includes(:node) }
      scope :negative_reserved_storage_bytes, -> { where('reserved_storage_bytes < 0') }
      scope :should_be_marked_as_orphaned, -> do
        where(zoekt_enabled_namespace: nil).or(where(replica: nil)).where.not(state: SHOULD_BE_DELETED_STATES)
      end

      scope :should_be_deleted, -> do
        where(state: SHOULD_BE_DELETED_STATES)
      end

      scope :with_mismatched_watermark_levels, -> do
        where <<~SQL.squish
          CASE
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_IDEAL_PERCENT_USED}
              THEN #{watermark_levels[:overprovisioned]}
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_LOW_WATERMARK}
              THEN #{watermark_levels[:healthy]}
            WHEN (used_storage_bytes / NULLIF(reserved_storage_bytes, 0)::float) < #{STORAGE_HIGH_WATERMARK}
              THEN #{watermark_levels[:low_watermark_exceeded]}
            ELSE #{watermark_levels[:high_watermark_exceeded]}
          END != watermark_level
        SQL
      end

      def self.update_used_storage_bytes!
        all.find_each do |zoekt_index|
          sum_for_index = 0

          Search::Zoekt::Repository.where(zoekt_index_id: zoekt_index.id).each_batch do |repo_batch|
            sum_for_index += repo_batch.sum(:size_bytes)
          end

          zoekt_index.update!(used_storage_bytes: sum_for_index) if sum_for_index != zoekt_index.used_storage_bytes
        end
      end

      def update_reserved_storage_bytes!
        # This number of bytes will put the index as the ideal storage utilization
        ideal_reserved_storage_bytes = used_storage_bytes / STORAGE_IDEAL_PERCENT_USED

        # Reservable space left on node in addition to the existing reservation made by the index
        max_reservable_storage_bytes = node.unclaimed_storage_bytes + reserved_storage_bytes.to_i

        # In case there is more requested bytes than available on the node, we reserve the minimum
        # amount that we have available.
        #
        # Note: this will also **decrease** the reservation if the total needed is now lower.
        new_reserved_bytes = [ideal_reserved_storage_bytes, max_reservable_storage_bytes].min

        return if new_reserved_bytes == reserved_storage_bytes

        self.reserved_storage_bytes = new_reserved_bytes
        self.watermark_level = appropriate_watermark_level
        save!
      rescue StandardError => err
        logger.error(build_structured_payload(
          message: 'Error attempting to update reserved_storage_bytes',
          index_id: id,
          error: err.message,
          new_reserved_bytes: new_reserved_bytes,
          reserved_storage_bytes: reserved_storage_bytes
        ))

        raise err
      end

      def free_storage_bytes
        reserved_storage_bytes.to_i - used_storage_bytes
      end

      def storage_percent_used
        used_storage_bytes / reserved_storage_bytes.to_f
      end

      def should_be_deleted?
        SHOULD_BE_DELETED_STATES.include? state.to_sym
      end

      private

      def appropriate_watermark_level
        case storage_percent_used
        when 0...STORAGE_IDEAL_PERCENT_USED then :overprovisioned
        when STORAGE_IDEAL_PERCENT_USED...STORAGE_LOW_WATERMARK then :healthy
        when STORAGE_LOW_WATERMARK...STORAGE_HIGH_WATERMARK then :low_watermark_exceeded
        else
          :high_watermark_exceeded
        end
      end

      def delete_from_index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(namespace_id, 'delete', zoekt_node_id)
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
