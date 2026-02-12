# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class DestroyService
      def initialize(project:, tracked_context_id:, current_user:, archive_vulnerabilities: true)
        @project = project
        @tracked_context_id = tracked_context_id
        @current_user = current_user
        @archive_vulnerabilities = archive_vulnerabilities
      end

      def execute
        tracked_context = find_tracked_context
        return not_found_error unless tracked_context
        return project_mismatch_error unless tracked_context.project_id == project.id
        return default_branch_error if tracked_context.is_default?

        handle_vulnerabilities if archive_vulnerabilities

        tracked_context.destroy!
        ServiceResponse.success(message: 'Tracked context removed')
      rescue ActiveRecord::RecordNotDestroyed => e
        ServiceResponse.error(message: "Failed to remove tracked context: #{e.message}")
      end

      private

      attr_reader :project, :tracked_context_id, :current_user, :archive_vulnerabilities

      def find_tracked_context
        # rubocop:disable CodeReuse/ActiveRecord -- This service is a reusable unit
        Security::ProjectTrackedContext.find_by(id: tracked_context_id)
        # rubocop:enable CodeReuse/ActiveRecord
      end

      def handle_vulnerabilities
        tracked_context = find_tracked_context
        tracked_context.vulnerability_reads.update_all(archived: true) if tracked_context
      end

      def not_found_error
        ServiceResponse.error(message: 'Tracked context not found')
      end

      def project_mismatch_error
        ServiceResponse.error(message: 'Tracked ref does not belong to specified project')
      end

      def default_branch_error
        ServiceResponse.error(message: 'Cannot untrack default branch')
      end
    end
  end
end
