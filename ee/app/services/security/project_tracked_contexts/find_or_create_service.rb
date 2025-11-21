# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    class FindOrCreateService
      include Gitlab::Utils::StrongMemoize

      def self.from_pipeline(pipeline)
        new(
          project: pipeline.project,
          context_name: pipeline.ref,
          context_type: pipeline.tag? ? :tag : :branch,
          is_default: pipeline.default_branch?
        )
      end

      def initialize(**params)
        @project = params[:project]
        @context_name = params[:context_name]
        @context_type = params[:context_type]
        @is_default = params[:is_default]
      end

      attr_reader :project, :context_name, :context_type, :is_default

      def execute
        return success(existing_context) if existing_context
        return cant_create_non_default_error unless is_default

        create_context
      end

      private

      def existing_context
        # rubocop:disable CodeReuse/ActiveRecord -- This service is a reusable unit
        Security::ProjectTrackedContext.find_by(project:, context_name:, context_type:)
        # rubocop:enable CodeReuse/ActiveRecord
      end
      strong_memoize_attr :existing_context

      def create_context
        tracked_context = Security::ProjectTrackedContext.create(
          project: project,
          context_name: context_name,
          context_type: context_type,

          # We only create contexts for the default branch and it must be tracked.
          is_default: true,
          state: Security::ProjectTrackedContext::STATES[:tracked]
        )

        return error(tracked_context) unless tracked_context.persisted?

        success(tracked_context)
      end

      def success(tracked_context)
        ServiceResponse.success(payload: { tracked_context: tracked_context })
      end

      def error(tracked_context)
        ServiceResponse.error(message: tracked_context.errors.full_messages)
      end

      def cant_create_non_default_error
        ServiceResponse.error(message: 'Expected context to already exist for non-default branches')
      end
    end
  end
end
