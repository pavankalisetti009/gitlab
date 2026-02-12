# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class DestroyService
      def initialize(tracked_context:, current_user:, archive_vulnerabilities: true)
        @tracked_context = tracked_context
        @current_user = current_user
        @archive_vulnerabilities = archive_vulnerabilities
      end

      attr_reader :tracked_context, :current_user, :archive_vulnerabilities

      def execute
        return not_found_error unless tracked_context&.persisted?
        return cannot_untrack_default_error if tracked_context.is_default?

        destroyed_context = tracked_context.dup

        handle_vulnerabilities if archive_vulnerabilities
        tracked_context.destroy!

        ServiceResponse.success(
          message: 'Tracked context removed',
          payload: { destroyed_context: destroyed_context }
        )
      rescue ActiveRecord::RecordNotDestroyed => e
        ServiceResponse.error(message: "Failed to remove tracked context: #{e.message}")
      end

      private

      def handle_vulnerabilities
        vulnerability_reads = tracked_context.vulnerability_reads

        return unless vulnerability_reads.any?

        vulnerability_reads.update_all(
          archived: true
        )
      end

      def not_found_error
        ServiceResponse.error(message: 'Ref not found')
      end

      def cannot_untrack_default_error
        ServiceResponse.error(message: 'Cannot untrack default branch')
      end
    end
  end
end
