# frozen_string_literal: true

module Sbom
  class DependencyPath < ::Gitlab::Database::SecApplicationRecord
    include IgnorableColumns

    self.table_name = 'sbom_occurrences'
    ignore_columns %w[created_at updated_at component_version_id pipeline_id source_id commit_sha
      component_id uuid package_manager component_name input_file_path licenses highest_severity vulnerability_count
      source_package_id archived traversal_ids ancestors reachability], remove_never: true

    MAX_DEPTH = 20

    attribute :id, :integer
    attribute :dependency_name, :string
    attribute :project_id, :integer
    attribute :full_path, :string, array: true
    attribute :version, :string, array: true
    attribute :is_cyclic, :boolean
    attribute :max_depth_reached, :boolean

    def self.find(occurrence_id:, project_id:)
      query = <<-SQL
        WITH RECURSIVE dependency_tree AS (
          SELECT
              so.id,
              sc.name as dependency_name,
              so.project_id,
              so.traversal_ids,
              ARRAY [a->>'name', sc.name] as full_path,
              ARRAY [a->>'version', versions.version] as version,
              concat_ws('>', concat_ws('@', a->>'name', a->>'version'), concat_ws('@', sc.name, versions.version)) as combined_path,
              false as is_cyclic,
              false as max_depth_reached
          FROM
              sbom_occurrences so
              inner join sbom_components sc on sc.id = so.component_id
              inner join sbom_component_versions versions on versions.id = so.component_version_id
              CROSS JOIN LATERAL jsonb_array_elements(so.ancestors) as a
          where
              so.id = :occurrence_id
              and so.project_id = :project_id
              and a->>'name' IS NOT NULL
          UNION
          ALL
          SELECT
              dt.id,
              dt.dependency_name,
              dt.project_id,
              dt.traversal_ids,
              ARRAY [a->>'name'] || dt.full_path,
              ARRAY [a->>'version'] || dt.version,
              concat_ws('>', concat_ws('@', a->>'name', a->>'version'), dt.combined_path),
              position(concat_ws('@', a->>'name', a->>'version') in dt.combined_path) > 0,
              array_length(dt.full_path, 1) = :max_depth
          FROM
              dependency_tree dt
              JOIN sbom_occurrences so ON so.traversal_ids = dt.traversal_ids
              join sbom_components sc ON sc.id = so.component_id and sc.name = dt.full_path[1]
              join sbom_component_versions versions on versions.id = so.component_version_id and versions.version = dt.version[1]
              CROSS JOIN LATERAL jsonb_array_elements(so.ancestors) as a
          WHERE
              array_length(dt.full_path, 1) <= :max_depth
              and so.project_id = :project_id
              and not dt.is_cyclic
              and a->>'name' IS NOT NULL
        )
        SELECT
            id,
            dependency_name,
            project_id,
            traversal_ids,
            full_path,
            combined_path,
            version,
            is_cyclic,
            max_depth_reached
        FROM
          dependency_tree
        WHERE NOT EXISTS (  -- Remove partial paths
            SELECT 1
            FROM dependency_tree dt2
            WHERE position(dependency_tree.combined_path in dt2.combined_path) > 0 -- Current path is a sub-path of another path
            AND dependency_tree.combined_path <> dt2.combined_path -- Don't remove yourself!
            AND NOT dependency_tree.is_cyclic -- Keep cyclic paths
        );
      SQL

      query_params = {
        project_id: project_id,
        occurrence_id: occurrence_id,
        max_depth: MAX_DEPTH
      }

      sql = sanitize_sql_array([query, query_params])

      DependencyPath.find_by_sql(sql)
    end

    def path
      full_path.each_with_index.map do |path, index|
        {
          name: path,
          version: version[index]
        }
      end
    end
  end
end
