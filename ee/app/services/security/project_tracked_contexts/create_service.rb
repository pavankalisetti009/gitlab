# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class CreateService < ::BaseService
      STATES = ::Security::ProjectTrackedContext::STATES

      def initialize(project, current_user = nil, params = {})
        super

        @context_name = params[:context_name]
        @context_type = params[:context_type]
        @is_default = params[:is_default] || false
        @track = params[:track] || false
      end

      def execute
        tracked_context = build_tracked_context

        return error_response(tracked_context) unless tracked_context.save

        success_response(tracked_context)
      end

      private

      attr_reader :context_name, :context_type, :is_default, :track

      def build_tracked_context
        project.security_project_tracked_contexts.build(
          context_name: context_name,
          context_type: context_type,
          is_default: is_default,
          state: track ? STATES[:tracked] : STATES[:untracked]
        )
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
    end
  end
end
