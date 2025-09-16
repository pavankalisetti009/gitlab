# frozen_string_literal: true

module Sbom
  class ComponentsFinder
    COMPONENT_NAMES_LIMIT = 30

    def initialize(namespace, query)
      @namespace = namespace
      @query = query.to_s
    end

    def execute
      base_relation
       .select_distinct(on: "name")
       .order_by_name
       .limit(COMPONENT_NAMES_LIMIT)
    end

    private

    attr_reader :namespace, :query

    def base_relation
      case namespace
      when Project
        project_relation
      when Group
        group_relation
      else
        Sbom::Component.none
      end
    end

    def project_relation
      Sbom::Component
        .for_project(namespace)
        .by_name(query)
    end

    # In addition we need to perform a loose index scan with custom collation for performance reasons.
    # Sorting can be unpredictable for words containing non-ASCII characters, but dependency names
    # are usually ASCII
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/442407#note_2099802302 for performance
    def group_relation
      # rubocop:disable CodeReuse/ActiveRecord -- context-specific
      # rubocop:disable GitlabSecurity/SqlInjection -- Sanitized with sanitize_sql_array
      Sbom::Component.where("id IN (#{group_query_sql})")
      # rubocop:enable GitlabSecurity/SqlInjection
      # rubocop:enable CodeReuse/ActiveRecord
    end

    def group_query_sql
      Sbom::Component.sanitize_sql_array([group_query_template, group_query_params])
    end

    def group_query_template
      <<~SQL
        WITH RECURSIVE component_names AS (
          SELECT
            *
          FROM (
              SELECT
                traversal_ids,
                component_name,
                component_id
              FROM
                sbom_occurrences
              WHERE
                traversal_ids >= '{:start_id}'
                AND traversal_ids < '{:end_id}'
                AND component_name LIKE :query COLLATE "C"
              ORDER BY
                sbom_occurrences.component_name COLLATE "C" ASC
              LIMIT 1
            ) sub_select
          UNION ALL
          SELECT
            lateral_query.traversal_ids,
            lateral_query.component_name,
            lateral_query.component_id
          FROM
            component_names,
            LATERAL (
              SELECT
                sbom_occurrences.traversal_ids,
                sbom_occurrences.component_name,
                sbom_occurrences.component_id
              FROM
                sbom_occurrences
              WHERE
                sbom_occurrences.traversal_ids >= '{:start_id}'
                AND sbom_occurrences.traversal_ids < '{:end_id}'
                AND component_name LIKE :query COLLATE "C"
                AND sbom_occurrences.component_name > component_names.component_name
              ORDER BY
                sbom_occurrences.component_name COLLATE "C" ASC
              LIMIT 1
            ) lateral_query
        )
        SELECT
          component_names.component_id AS id
        FROM
          component_names
      SQL
    end

    def group_query_params
      {
        start_id: namespace.traversal_ids,
        end_id: namespace.next_traversal_ids,
        query: "#{sanitized_query}%"
      }
    end

    def sanitized_query
      Sbom::Component.sanitize_sql_like(query)
    end
  end
end
