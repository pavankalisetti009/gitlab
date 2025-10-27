# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class AdHocIndexingWorker
        include ApplicationWorker
        include Gitlab::Utils::StrongMemoize
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
          return false unless project_eligible_for_indexing?(project)

          repository = create_repository_record(project)
          RepositoryIndexWorker.perform_async(repository.id)
        end

        private

        def project_eligible_for_indexing?(project)
          return false if Feature.disabled?(:active_context_code_index_project, project)
          return false unless project.project_setting.duo_features_enabled
          return false unless enabled_namespace_for_project(project)

          true
        end

        def create_repository_record(project)
          Ai::ActiveContext::Code::Repository.create(
            project_id: project.id,
            enabled_namespace_id: enabled_namespace_for_project(project).id,
            connection_id: active_connection.id,
            state: :pending
          )
        end

        def enabled_namespace_for_project(project)
          strong_memoize_with(:enabled_namespace_for_project, project) do
            Ai::ActiveContext::Code::EnabledNamespace.find_enabled_namespace(active_connection, project.root_namespace)
          end
        end

        def active_connection
          Ai::ActiveContext::Connection.active
        end
        strong_memoize_attr :active_connection
      end
    end
  end
end
