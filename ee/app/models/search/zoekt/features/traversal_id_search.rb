# frozen_string_literal: true

module Search
  module Zoekt
    module Features
      class TraversalIdSearch < BaseFeature
        self.minimum_schema_version = 2531

        def preflight_checks_passed?
          Feature.enabled?(:zoekt_traversal_id_queries, user) && large_amount_of_projects?
        end

        private

        def large_amount_of_projects?
          return false if project_search?
          return true if global_search?
          return true if Feature.enabled?(:zoekt_disable_large_project_checks, namespace)

          count_limit = ::Search::Zoekt::Settings.minimum_projects_for_traversal_id_search
          return true if count_limit <= 1

          ::Namespace.by_root_id(
            namespace.root_ancestor.id
          ).project_namespaces.limit(count_limit).count >= count_limit
        end

        def project_search?
          project_id.present?
        end

        def global_search?
          !project_id.present? && !namespace.present?
        end
      end
    end
  end
end
