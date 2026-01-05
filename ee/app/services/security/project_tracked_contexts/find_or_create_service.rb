# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    # FindOrCreateService encapsulates the logic to find or create `Security::ProjectTrackedContext` records.
    # If the tracked context does not exist, it will be created, but only if it's for the default branch.
    # Otherwise, it expects the context to already exist.
    class FindOrCreateService
      include Gitlab::Utils::StrongMemoize

      def self.from_pipeline(pipeline, allow_untracked: false)
        new(
          project: pipeline.project,
          context_name: pipeline.ref,
          context_type: pipeline.tag? ? :tag : :branch,
          is_default: pipeline.default_branch?,
          allow_untracked: allow_untracked
        )
      end

      def self.project_default_branch(project)
        new(
          project: project,
          context_name: project.default_branch,
          context_type: :branch,
          is_default: true
        )
      end

      def initialize(**params)
        @project = params[:project]
        @context_name = params[:context_name]
        @context_type = params[:context_type]
        @is_default = params[:is_default]
        @allow_untracked = params[:allow_untracked] || false
      end

      attr_reader :project, :context_name, :context_type, :is_default, :allow_untracked

      def execute
        if existing_context.present?
          return success(existing_context) if existing_context.tracked? || allow_untracked

          return ServiceResponse.error(message: 'Context is not tracked')
        end

        return cant_create_non_default_error unless is_default || allow_untracked

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
        state = if !is_default && @allow_untracked
                  Security::ProjectTrackedContext::STATES[:untracked]
                else
                  Security::ProjectTrackedContext::STATES[:tracked]
                end

        tracked_context = Security::ProjectTrackedContext.create(
          project: project,
          context_name: context_name,
          context_type: context_type,
          is_default: is_default,
          state: state
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
