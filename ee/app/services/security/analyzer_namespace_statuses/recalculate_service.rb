# frozen_string_literal: true

module Security
  module AnalyzerNamespaceStatuses
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
        recalculate_analyzer_namespaces_statuses
      end

      private

      attr_reader :project_id, :group, :deleted_project

      def recalculate_analyzer_namespaces_statuses
        # recalculating for the group namespace could return a diff for each analyzer type
        # in case of actual status difference
        namespace_diffs = AdjustmentService.new([group.id]).execute
        return unless namespace_diffs.present? && !namespace_diffs.empty?

        ancestors_diffs_with_metadata = get_ancestors_diffs_with_metadata(namespace_diffs)
        return unless ancestors_diffs_with_metadata.present?

        # Propagate the change to the group ancestors
        AncestorsUpdateService.execute(ancestors_diffs_with_metadata)
      end

      def verify_no_project_related_records
        # Deleting project triggers async delete with loose foreign keys. Verify no records exists before recalculating
        AnalyzerProjectStatus.by_projects(project_id).delete_all
      end

      def get_ancestors_diffs_with_metadata(namespace_diffs)
        # Remove the project's group which has already have the updated value due to the AdjustmentService.
        # Create a diff for its ancestors only
        first_diff = namespace_diffs.first

        traversal_ids = first_diff["traversal_ids"].gsub(/[{}]/, '').split(',').map(&:to_i)
        return unless traversal_ids.length > 1

        traversal_ids.pop # remove group id since it was already adjusted using the AdjustmentService
        namespace_id = traversal_ids.last

        {
          diff: build_diffs(namespace_diffs),
          namespace_id: namespace_id,
          traversal_ids: traversal_ids
        }
      end

      def build_diffs(namespace_diffs)
        diffs = {}

        namespace_diffs.each do |diff|
          # Find the analyzer type name from the enum
          analyzer_name = Enums::Security.analyzer_types.key(diff["analyzer_type"])

          diffs[analyzer_name] = {
            "success" => diff["success"],
            "failed" => diff["failure"]
          }
        end

        diffs
      end
    end
  end
end
