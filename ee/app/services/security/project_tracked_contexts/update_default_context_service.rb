# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class UpdateDefaultContextService < ::BaseService
      def initialize(project, current_user = nil)
        super
      end

      def execute
        return error_no_default_branch unless project.default_branch.present?

        default_context = find_or_initialize_default_context

        return success_response(default_context) if default_context.context_name == project.default_branch

        default_context.context_name = project.default_branch

        return error_response(default_context) unless default_context.save

        success_response(default_context)
      end

      private

      def find_or_initialize_default_context
        # Find existing default context or build a new one
        project.security_project_tracked_contexts.default_branch.first_or_initialize do |context|
          context.context_type = :branch
          context.is_default = true
          context.state = ::Security::ProjectTrackedContext::STATES[:tracked]
        end
      end

      def success_response(tracked_context)
        ServiceResponse.success(
          payload: {
            tracked_context: tracked_context
          }
        )
      end

      def error_response(tracked_context)
        ServiceResponse.error(
          message: tracked_context.errors.full_messages.join(', '),
          payload: { tracked_context: tracked_context }
        )
      end

      def error_no_default_branch
        ServiceResponse.error(
          message: 'Project does not have a default branch'
        )
      end
    end
  end
end
