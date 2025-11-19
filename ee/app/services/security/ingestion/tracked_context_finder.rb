# frozen_string_literal: true

module Security
  module Ingestion
    class TrackedContextFinder
      include Gitlab::Utils::StrongMemoize

      def find_or_create_from_pipeline(pipeline)
        cached_context = pipeline_cache[pipeline.id]

        return cached_context if cached_context

        tracked_context = find(pipeline) || create!(pipeline)

        pipeline_cache[pipeline.id] ||= tracked_context

        tracked_context
      end

      private

      def pipeline_cache
        {}
      end
      strong_memoize_attr :pipeline_cache

      def find(pipeline)
        Security::ProjectTrackedContext.find_by_pipeline(pipeline)
      end

      def create!(pipeline)
        check_default_branch!(pipeline)

        Security::ProjectTrackedContext.create!(
          project: pipeline.project,
          context_name: pipeline.ref,
          context_type: :branch,
          state: Security::ProjectTrackedContext::STATES[:tracked],
          is_default: true
        )
      end

      def check_default_branch!(pipeline)
        return if pipeline.default_branch?

        raise ArgumentError, 'Expected tracked context to already exist for non-default branches'
      end
    end
  end
end
