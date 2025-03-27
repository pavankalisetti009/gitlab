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
          task_states = tasks.each_with_object(valid: [], orphaned: [], skipped: [], done: []) do |task, states|
            case determine_task_state(task)
            when :done
              states[:done] << task.id
            when :orphaned
              states[:orphaned] << task.id
            when :skipped
              states[:skipped] << task.id
            when :valid
              next unless processed_project_identifiers.add?(task.project_identifier)

              states[:valid] << task.id

              yield task
              count += 1
            end

            break states if count >= limit
          end

          update_task_states(states: task_states)
          break if count >= limit
        end
      end

      def self.task_iterator
        scope = processing_queue.with_project.order(:perform_at, :id)
        Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
      end

      def self.determine_task_state(task)
        return :valid if task.delete_repo?

        project = task.zoekt_repository&.project
        return :orphaned unless project

        return :skipped if task.zoekt_repository.failed?

        if Feature.disabled?(:zoekt_index_pending_delete_repos, Feature.current_request) && project.pending_delete
          return :skipped
        end

        # Mark tasks as done since we have nothing to index
        return :done unless project.repo_exists?

        :valid
      end

      def self.update_task_states(states:)
        id_in(states[:orphaned]).update_all(state: :orphaned, updated_at: Time.current) if states[:orphaned].any?
        id_in(states[:skipped]).update_all(state: :skipped, updated_at: Time.current) if states[:skipped].any?

        if states[:valid].any?
          id_in(states[:valid]).where.not(state: [:orphaned, :skipped, :done, :failed]).update_all(
            state: :processing, updated_at: Time.current
          )
        end

        return unless states[:done].any?

        done_tasks = id_in(states[:done])
        done_tasks.update_all(state: :done, updated_at: Time.current)
        Repository.id_in(done_tasks.select(:zoekt_repository_id)).update_all(state: :ready, updated_at: Time.current)
      end

      def set_project_identifier
        self.project_identifier ||= zoekt_repository&.project_identifier
      end
    end
  end
end
