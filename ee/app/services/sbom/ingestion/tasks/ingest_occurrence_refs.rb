# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestOccurrenceRefs < Base
        include Gitlab::Utils::StrongMemoize

        self.model = Sbom::OccurrenceRef

        private

        def after_ingest; end

        def insert_attributes
          return [] if tracked_context.blank?

          occurrence_maps.map do |occurrence_map|
            {
              sbom_occurrence_id: occurrence_map.occurrence_id,
              security_project_tracked_context_id: tracked_context.id,
              pipeline_id: pipeline.id,
              project_id: project.id,
              commit_sha: commit_sha
            }
          end
        end

        def tracked_context
          existing_context || new_context
        end
        strong_memoize_attr :tracked_context

        def existing_context
          pipeline.tag? ? tag_context : branch_context
        end

        def tag_context
          project.security_project_tracked_contexts
            .for_ref(ref_name)
            .tag
            .first
        end

        def branch_context
          project.security_project_tracked_contexts
            .for_ref(ref_name)
            .branch
            .first
        end

        def branch_ref?
          project.repository.branch_exists?(ref_name)
        end
        strong_memoize_attr :branch_ref?

        def commit_sha
          pipeline.sha
        end

        def ref_name
          pipeline.ref
        end

        def new_context
          return unless default_branch?

          project.security_project_tracked_contexts.create!(
            context_name: ref_name,
            context_type: :branch,
            is_default: true,
            state: Security::ProjectTrackedContext::STATES[:tracked]
          )
        end

        def default_branch?
          branch_ref? && project.default_branch == ref_name
        end
      end
    end
  end
end
