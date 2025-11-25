# frozen_string_literal: true

module Security
  module Ingestion
    class TrackedContextFinder
      include Gitlab::Utils::StrongMemoize

      def find_or_create_from_pipeline(pipeline)
        return pipeline_cache[pipeline.id] if pipeline_cache.key?(pipeline.id)

        pipeline_cache[pipeline.id] ||= find_or_create_context(pipeline)
      end

      private

      def pipeline_cache
        {}
      end
      strong_memoize_attr :pipeline_cache

      def find_or_create_context(pipeline)
        result = Security::ProjectTrackedContexts::FindOrCreateService.from_pipeline(pipeline).execute

        raise ArgumentError, result.message unless result.success?

        result.payload[:tracked_context]
      end
    end
  end
end
