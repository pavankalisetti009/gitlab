# frozen_string_literal: true

module Search
  module Zoekt
    class Task < ApplicationRecord
      include PartitionedTable
      include EachBatch
      include BulkInsertSafe

      PARTITION_DURATION = 1.day
      PARTITION_CLEANUP_THRESHOLD = 7.days
      PROCESSING_BATCH_SIZE = 100
      RETRY_DELAY = 5.minutes

      self.table_name = 'zoekt_tasks'
      self.primary_key = :id

      ignore_column :partition_id, remove_never: true
      attribute :retries_left, default: 3

      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :tasks, class_name: '::Search::Zoekt::Node'
      belongs_to :zoekt_repository, inverse_of: :tasks, class_name: '::Search::Zoekt::Repository'

      before_validation :set_project_identifier

      scope :for_partition, ->(partition) { where(partition_id: partition) }
      scope :with_project, -> { includes(zoekt_repository: :project) }
      scope :join_nodes, -> { joins(:node) }
      scope :perform_now, -> { where(perform_at: (..Time.zone.now)) }
      scope :pending_or_processing, -> { where(state: %i[pending processing]) }
      scope :processing_queue, -> { perform_now.pending_or_processing }

      enum state: {
        pending: 0,
        processing: 1,
        done: 10,
        skipped: 250,
        failed: 255,
        orphaned: 256
      }

      enum task_type: {
        index_repo: 0,
        force_index_repo: 1,
        delete_repo: 50
      }

      partitioned_by :partition_id,
        strategy: :sliding_list,
        next_partition_if: ->(active_partition) { next_partition?(active_partition) },
        detach_partition_if: ->(partition) { detach_partition?(partition) }

      def self.next_partition?(active_partition)
        oldest_record_in_partition = Task
          .select(:id, :created_at)
          .for_partition(active_partition.value)
          .order(:id)
          .first

        oldest_record_in_partition.present? && oldest_record_in_partition.created_at < PARTITION_DURATION.ago
      end

      def self.detach_partition?(partition)
        newest_task_older(partition, PARTITION_CLEANUP_THRESHOLD) && no_pending_or_processing(partition)
      end

      def self.newest_task_older(partition, duration)
        newest_record = Task.select(:id, :created_at).for_partition(partition.value).order(:id).last
        return true if newest_record.nil?

        newest_record.created_at < duration.ago
      end

      def self.no_pending_or_processing(partition)
        !Task.for_partition(partition.value).join_nodes.pending_or_processing.exists?
      end

      def self.each_task_for_processing(limit:)
        return unless block_given?

        process_tasks(limit) do |task|
          yield task
        end
      end

      private

      def self.process_tasks(limit)
        count = 0
        processed_project_identifiers = Set.new

        task_iterator.each_batch(of: PROCESSING_BATCH_SIZE) do |tasks|
          task_states = tasks.each_with_object(orphaned: [], skipped: []) do |task, states|
            case handle_invalid_task(task)
            in [:orphaned, task_id]
              states[:orphaned] << task_id
            in [:skipped, task_id]
              states[:skipped] << task_id
            in [:valid, nil]
              next unless processed_project_identifiers.add?(task.project_identifier)

              yield task
              count += 1
            end

            break states if count >= limit
          end

          update_task_states(tasks, orphaned_task_ids: task_states[:orphaned],
            skipped_task_ids: task_states[:skipped])
          break if count >= limit
        end
      end

      def self.task_iterator
        scope = processing_queue.with_project.order(:perform_at, :id)
        Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
      end

      def self.handle_invalid_task(task)
        return [:valid, nil] if task.delete_repo?

        project = task.zoekt_repository&.project
        return [:orphaned, task.id] unless project && project.repo_exists?

        return [:skipped, task.id] if task.zoekt_repository.failed? || project.pending_delete

        [:valid, nil]
      end

      def self.update_task_states(tasks, orphaned_task_ids:, skipped_task_ids:)
        tasks.where(id: orphaned_task_ids).update_all(state: :orphaned) if orphaned_task_ids.any?
        tasks.where(id: skipped_task_ids).update_all(state: :skipped) if skipped_task_ids.any?
        tasks.where.not(state: [:orphaned, :skipped]).update_all(state: :processing)
      end

      def set_project_identifier
        self.project_identifier ||= zoekt_repository&.project_identifier
      end
    end
  end
end
