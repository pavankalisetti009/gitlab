# frozen_string_literal: true

module Sbom
  class ComponentVersionsFinder
    def initialize(object, component_name)
      @object = object
      @component_name = component_name
    end

    def execute
      base_relation
        .select_distinct(on: "version")
        .order_by_version
    end

    private

    attr_reader :object, :component_name

    def base_relation
      case object
      when Project
        project_relation
      when Group
        group_relation
      else
        raise ArgumentError, "can't find components for #{object.class.name}"
      end
    end

    def project_relation
      Sbom::ComponentVersion
        .by_project(object)
        .by_component_name(component_name)
    end

    def group_relation
      # rubocop:disable CodeReuse/ActiveRecord -- context-specific
      # rubocop:disable GitlabSecurity/SqlInjection -- Sanitized with sanitize_sql_array
      Sbom::ComponentVersion.where("id IN (#{group_query_sql})")
      # rubocop:enable GitlabSecurity/SqlInjection
      # rubocop:enable CodeReuse/ActiveRecord
    end

    def group_query_sql
      Sbom::ComponentVersion.sanitize_sql_array([group_query_template, group_query_params])
    end

    def group_query_template
      <<~SQL
        WITH RECURSIVE component_versions AS (
          SELECT
            *
          FROM (
              SELECT
                traversal_ids,
                component_name,
                component_version_id
              FROM
                sbom_occurrences
              WHERE
                traversal_ids >= '{:start_id}'
                AND traversal_ids < '{:end_id}'
                AND component_name = :component_name COLLATE "C"
              ORDER BY
                sbom_occurrences.traversal_ids ASC,
                sbom_occurrences.component_name COLLATE "C" ASC,
                sbom_occurrences.component_version_id ASC
              LIMIT 1
            ) sub_select
          UNION ALL
          SELECT
            lateral_query.traversal_ids,
            lateral_query.component_name,
            lateral_query.component_version_id
          FROM
            component_versions,
            LATERAL (
              SELECT
                sbom_occurrences.traversal_ids,
                sbom_occurrences.component_name,
                sbom_occurrences.component_version_id
              FROM
                sbom_occurrences
              WHERE
                sbom_occurrences.traversal_ids >= '{:start_id}'
                AND sbom_occurrences.traversal_ids < '{:end_id}'
                AND (sbom_occurrences.traversal_ids,
                    sbom_occurrences.component_name,
                    sbom_occurrences.component_version_id) > (component_versions.traversal_ids,
                    component_versions.component_name,
                    component_versions.component_version_id)
                AND component_name = :component_name COLLATE "C"
              ORDER BY
                sbom_occurrences.traversal_ids ASC,
                sbom_occurrences.component_name COLLATE "C" ASC,
                sbom_occurrences.component_version_id ASC
              LIMIT 1
            ) lateral_query
        )
        SELECT
          component_versions.component_version_id AS id
        FROM
          component_versions
      SQL
    end

    def group_query_params
      {
        start_id: object.traversal_ids,
        end_id: object.next_traversal_ids,
        component_name: component_name
      }
    end
  end
end
