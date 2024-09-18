# frozen_string_literal: true

module Search
  module Zoekt
    class IndexingTaskService
      REINDEXING_CHANCE_PERCENTAGE = 0.5

      def self.execute(...)
        new(...).execute
      end

      def initialize(project_id, task_type, node_id: nil, root_namespace_id: nil, force: false, delay: nil)
        @project_id = project_id
        @project = Project.find_by_id(project_id)
        @task_type = task_type.to_sym
        @node_id = node_id
        @root_namespace_id = root_namespace_id || @project&.root_ancestor&.id
        @force = force
        @delay = delay
      end

      def execute
        return false unless preflight_check?

        current_task_type = random_force_reindexing? ? :force_index_repo : task_type
        Router.fetch_indices_for_indexing(project_id, root_namespace_id: root_namespace_id).find_each do |idx|
          perform_at = Time.current
          perform_at += delay if delay
          ApplicationRecord.transaction do
            Repository.create_tasks(
              project_id: project_id, zoekt_index: idx, task_type: current_task_type, perform_at: perform_at
            )
          end
        end
      end

      private

      attr_reader :project_id, :project, :node_id, :root_namespace_id, :force, :task_type, :delay

      def preflight_check?
        task_type == :delete_repo || project.present?
      end

      def random_force_reindexing?
        return true if task_type == :force_index_repo
        return false unless task_type == :index_repo
        return false if Feature.disabled?(:zoekt_random_force_reindexing, project, type: :ops)

        rand * 100 <= REINDEXING_CHANCE_PERCENTAGE
      end
    end
  end
end
