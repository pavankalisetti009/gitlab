# frozen_string_literal: true

module Vulnerabilities
  module NamespaceStatistics
    class RecalculateService
      def self.execute(project_id, group, deleted_project: false)
        new(project_id, group, deleted_project).execute
      end

      def initialize(project_id, group, deleted_project)
        @project_id = project_id
        @group = group
        @deleted_project = deleted_project
      end

      def execute
        return unless project_id.present? && group.present?

        verify_no_project_related_records if deleted_project
        recalculate_namespaces_statistics
      end

      private

      attr_reader :project_id, :group, :deleted_project

      def recalculate_namespaces_statistics
        # recalculating for the group namespace should return a single diff in case of actual statistics difference
        namespace_diffs = AdjustmentService.new([group.id]).execute
        return unless namespace_diffs.present? && namespace_diffs.length == 1

        ancestors_diff = get_ancestors_diff(namespace_diffs)
        return unless ancestors_diff.present?

        # Propagate the change to the group ancestors
        UpdateService.execute([ancestors_diff])
      end

      def verify_no_project_related_records
        # Deleting project triggers async delete with loose foreign keys. Verify no records exists before recalculating
        Statistic.by_projects(project_id).delete_all
      end

      def get_ancestors_diff(namespace_diffs)
        # Remove the project's group which has already have the updated value due to the AdjustmentService.
        # Create a diff for its ancestors only
        namespace_diff = namespace_diffs.first
        ids = namespace_diff["traversal_ids"].gsub(/[{}]/, '').split(',').map(&:to_i)
        return unless ids.length > 1

        ids.pop # remove the project's group id
        namespace_diff["namespace_id"] = ids.last
        namespace_diff["traversal_ids"] = "{#{ids.join(',')}}"

        namespace_diff
      end
    end
  end
end
