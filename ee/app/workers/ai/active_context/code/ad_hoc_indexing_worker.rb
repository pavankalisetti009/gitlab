# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class AdHocIndexingWorker
        include ApplicationWorker
        include Ai::ActiveContext::Concerns::CodeEligibility
        prepend ::Geo::SkipSecondary

        feature_category :global_search
        deduplicate :until_executed
        data_consistency :sticky
        urgency :low
        idempotent!
        defer_on_database_health_signal :gitlab_main, [:p_ai_active_context_code_repositories], 10.minutes

        def perform(project_id)
          return false unless ::Ai::ActiveContext::Collections::Code.indexing?

          project = Project.find_by_id(project_id)
          return false unless project
          return false if Ai::ActiveContext::Code::Repository.for_project(project.id).exists?
          return false unless project_eligible_for_indexing?(project, force_cache_reload: true)

          repository = create_repository_record(project)
          RepositoryIndexWorker.perform_async(repository.id)
        end

        private

        def create_repository_record(project)
          Ai::ActiveContext::Code::Repository.create(
            project_id: project.id,
            enabled_namespace_id: enabled_namespace_for_project(project).id,
            connection_id: active_connection.id,
            state: :pending
          )
        end
      end
    end
  end
end
