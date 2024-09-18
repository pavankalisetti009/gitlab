# frozen_string_literal: true

module Search
  module Zoekt
    class CallbackService
      def initialize(node, params)
        @node = node
        @params = params.with_indifferent_access
      end

      def execute
        return unless task

        params[:success] ? process_success : process_failure
      end

      def self.execute(...)
        new(...).execute
      end

      private

      attr_reader :node, :params

      def task
        id = params.dig(:payload, :task_id)
        return unless id

        node.tasks.find_by_id(id)
      end

      def process_success
        return if task.done?

        repo = task.zoekt_repository
        ApplicationRecord.transaction do
          if task.delete_repo?
            repo&.destroy!
          else
            repo.indexed_at = Time.current
            repo.state = :ready if repo.pending? || repo.initializing?
            size_bytes = params.dig(:additional_payload, :repo_stats, :size_in_bytes)
            index_file_count = params.dig(:additional_payload, :repo_stats, :index_file_count)
            repo.size_bytes = size_bytes if size_bytes
            repo.index_file_count = index_file_count if index_file_count
            repo.retries_left = Repository.columns_hash['retries_left'].default
            repo.save!
          end

          task.done!
        end
      end

      def process_failure
        return if task.failed?
        return task.update!(retries_left: task.retries_left.pred) if task.retries_left > 1

        task.update!(state: :failed, retries_left: 0)
        publish_task_failed_event_for(task)
      end

      def publish_task_failed_event_for(task)
        event = TaskFailedEvent.new(data: { zoekt_repository_id: task.zoekt_repository_id })
        Gitlab::EventStore.publish(event)
      end
    end
  end
end
