# frozen_string_literal: true

module Ai
  module ActiveContext
    module Concerns
      module CodeEligibility
        include Gitlab::Utils::StrongMemoize

        extend ActiveSupport::Concern

        CODE_ELIGIBILITY_CACHE_KEY = "active_context_code_eligible_project_%{project_id}"
        CODE_ELIGIBILITY_CACHE_EXPIRY = 1.minute

        protected

        def project_eligible_for_indexing?(project_obj_or_id, force_cache_reload: false)
          Rails.cache.fetch(
            cache_key(project_obj_or_id),
            expires_in: CODE_ELIGIBILITY_CACHE_EXPIRY,
            force: force_cache_reload
          ) do
            project = find_project(project_obj_or_id)

            break false unless project
            break false unless Feature.enabled?(:active_context_code_index_project, project)
            break false unless project.project_setting.duo_features_enabled
            break false unless enabled_namespace_for_project(project)&.ready?

            true
          end
        end

        def cache_key(project_obj_or_id)
          project_id = project_obj_or_id.is_a?(Project) ? project_obj_or_id.id : project_obj_or_id
          format(CODE_ELIGIBILITY_CACHE_KEY, project_id: project_id)
        end

        def find_project(project_obj_or_id)
          return project_obj_or_id if project_obj_or_id.is_a?(Project)

          Project.find_by_id(project_obj_or_id)
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
