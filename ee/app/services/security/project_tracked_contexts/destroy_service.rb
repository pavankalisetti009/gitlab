# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class DestroyService
      def initialize(tracked_context:, current_user:)
        @tracked_context = tracked_context
        @current_user = current_user
      end

      attr_reader :tracked_context, :current_user

      def execute
        return not_found_error unless tracked_context&.persisted?
        return permission_error unless can_manage_contexts?
        return cannot_delete_default_error if tracked_context.is_default?

        tracked_context.destroy!
        ServiceResponse.success(message: 'Tracked context removed')
      rescue ActiveRecord::RecordNotDestroyed => e
        ServiceResponse.error(message: "Failed to remove tracked context: #{e.message}")
      end

      private

      def can_manage_contexts?
        return true unless current_user

        Ability.allowed?(current_user, :delete_security_project_tracked_ref, tracked_context.project)
      end

      def permission_error
        ServiceResponse.error(message: 'Permission denied')
      end

      def not_found_error
        ServiceResponse.error(message: 'Tracked context not found')
      end

      def cannot_delete_default_error
        ServiceResponse.error(message: 'Cannot delete default branch tracking')
      end
    end
  end
end
