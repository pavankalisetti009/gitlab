# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestOccurrences < Base
        include Gitlab::Utils::StrongMemoize

        self.model = Sbom::Occurrence
        self.unique_by = %i[uuid].freeze
        self.uses = %i[id uuid].freeze

        CONTAINER_IMAGE_PREFIX = "container-image:"
        PIPELINE_ATTRIBUTES_KEYS = %i[pipeline_id commit_sha].freeze
        VulnerabilityData = Struct.new(
          'VulnerabilityData',
          :vulnerabilities_info,
          :occurrence_map,
          :key) do
          include Gitlab::Utils::StrongMemoize

          def count
            vulnerabilities_info.dig(key, :vulnerability_count) || 0
          end

          def highest_severity
            vulnerabilities_info.dig(key, :highest_severity)
          end

          def vulnerability_ids
            vulnerabilities_info.dig(key, :vulnerability_ids) || []
          end

          private

          def key
            @key ||= [
              occurrence_map.name,
              occurrence_map.version,
              occurrence_map.input_file_path&.delete_prefix(CONTAINER_IMAGE_PREFIX)
            ]
          end
        end

        private

        def after_ingest
          each_pair do |occurrence_map, row|
            occurrence_map.occurrence_id = row.first
          end

          existing_occurrences_by_uuid.each_pair do |uuid, occurrence|
            indexed_occurrence_maps[[uuid]].each { |map| map.occurrence_id = occurrence.id }
          end
        end

        def attributes
          Gitlab::Database.allow_cross_joins_across_databases(
            url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/480330'
          ) do
            ensure_uuids
            occurrence_maps.uniq!(&:uuid)
            occurrence_maps.filter_map do |occurrence_map|
              uuid = occurrence_map.uuid

              vulnerability_data = VulnerabilityData.new(vulnerabilities_info, occurrence_map)

              new_attributes = {
                project_id: project.id,
                pipeline_id: pipeline.id,
                component_id: occurrence_map.component_id,
                component_version_id: occurrence_map.component_version_id,
                source_id: occurrence_map.source_id,
                source_package_id: occurrence_map.source_package_id,
                commit_sha: pipeline.sha,
                uuid: uuid,
                package_manager: occurrence_map.packager,
                input_file_path: occurrence_map.input_file_path,
                licenses: licenses.fetch(occurrence_map.report_component, []),
                component_name: occurrence_map.name,
                highest_severity: vulnerability_data.highest_severity,
                vulnerability_count: vulnerability_data.count,
                traversal_ids: project.namespace.traversal_ids,
                archived: project.archived,
                ancestors: occurrence_map.ancestors,
                reachability: occurrence_map.reachability
              }

              occurrence_map.vulnerability_ids = vulnerability_data.vulnerability_ids

              if attributes_changed?(new_attributes)
                # Remove updated items from the list so that we don't have to iterate over them
                # twice when setting the ids in `after_ingest`.
                existing_occurrences_by_uuid.delete(uuid)

                new_attributes
              end
            end
          end
        end

        def vulnerabilities_info
          @vulnerabilities_info ||= build_vulnerabilities_info
        end

        def build_vulnerabilities_info
          # rubocop:disable CodeReuse/ActiveRecord -- highly customized query
          occurrence_maps_values = occurrence_maps.map do |om|
            [om.name, om.version, om.input_file_path&.delete_prefix(CONTAINER_IMAGE_PREFIX)]
          end

          as_values = Arel::Nodes::ValuesList.new(occurrence_maps_values).to_sql

          # We don't use Gitlab::SQL::CTE (or Arel directly) because
          # this table is coming from a VALUES list
          cte_sql = "WITH occurrence_maps (name, version, path) AS (#{as_values})"

          select_sql = <<-SQL
             occurrence_maps.name,
             occurrence_maps.version,
             occurrence_maps.path,
             array_to_json(array_agg(vulnerability_occurrences.vulnerability_id)) as vulnerability_ids,
             MAX(vulnerability_occurrences.severity) as highest_severity,
             COUNT(vulnerability_occurrences.id) as vulnerability_count
          SQL

          join_sql = <<-SQL
            JOIN occurrence_maps
            ON occurrence_maps.name = (vulnerability_occurrences.location -> 'dependency' -> 'package' ->> 'name')::text
            AND occurrence_maps.version = (vulnerability_occurrences.location -> 'dependency' ->> 'version')::text
            AND occurrence_maps.path = COALESCE(
              vulnerability_occurrences.location ->> 'file',
              vulnerability_occurrences.location ->> 'image'
            )::text
          SQL

          query = ::Vulnerabilities::Finding
                    .select(select_sql)
                    .joins(join_sql)
                    .by_report_types(%i[container_scanning dependency_scanning])
                    .by_projects(project)
                    .group("occurrence_maps.name, occurrence_maps.version, occurrence_maps.path")

          full_query = [cte_sql, query.to_sql].join("\n")
          results = ::Vulnerabilities::Finding.connection.execute(full_query)

          results.each_with_object({}) do |row, result|
            key = row.values_at('name', 'version', 'path')
            value = {
              highest_severity: row['highest_severity'],
              vulnerability_count: row['vulnerability_count'],
              vulnerability_ids: ::Gitlab::Json.parse(row['vulnerability_ids']).filter_map do |id|
                id_i = id.to_i
                id_i if id_i > 0
              end
            }
            result[key] = value
          end
          # rubocop:enable CodeReuse/ActiveRecord
        end

        def uuids
          occurrence_maps.map do |map|
            map.uuid = uuid(map)
          end
        end
        strong_memoize_attr :uuids

        alias_method :ensure_uuids, :uuids

        def existing_occurrences_by_uuid
          return {} unless uuids.present?

          Sbom::Occurrence.by_uuids(uuids).index_by(&:uuid)
        end
        strong_memoize_attr :existing_occurrences_by_uuid

        def uuid(occurrence_map)
          uuid_attributes = occurrence_map.to_h.slice(
            :component_id,
            :component_version_id,
            :source_id
          ).merge(project_id: project.id)

          ::Sbom::OccurrenceUUID.generate(**uuid_attributes)
        end

        # Return true if the new attributes differ from the existing attributes
        # for the same uuid.
        def attributes_changed?(new_attributes)
          uuid = new_attributes[:uuid]
          existing_occurrence = existing_occurrences_by_uuid[uuid]

          return true unless existing_occurrence

          compared_attributes = new_attributes.keys - PIPELINE_ATTRIBUTES_KEYS
          stable_new_attributes = new_attributes.deep_symbolize_keys.slice(*compared_attributes)
          stable_existing_attributes = existing_occurrence.attributes.deep_symbolize_keys.slice(*compared_attributes)

          stable_new_attributes != stable_existing_attributes
        end

        def licenses
          Licenses.new(project, occurrence_maps)
        end
        strong_memoize_attr :licenses

        # This can be deleted after https://gitlab.com/gitlab-org/gitlab/-/issues/370013
        class Licenses
          include Gitlab::Utils::StrongMemoize

          attr_reader :project, :components

          def initialize(project, occurrence_maps)
            @project = project
            @components = occurrence_maps.filter_map do |occurrence_map|
              next if occurrence_map.report_component.purl.blank?

              Hashie::Mash.new(occurrence_map.to_h.slice(
                :name,
                :purl_type,
                :version
              ).merge(path: occurrence_map.input_file_path))
            end
          end

          def fetch(report_component, default = [])
            licenses.fetch(report_component.key, default)
          end

          private

          def licenses
            finder = Gitlab::LicenseScanning::PackageLicenses.new(
              components: components
            )
            finder.fetch.each_with_object({}) do |result, hash|
              licenses = result
                           .fetch(:licenses, [])
                           .filter_map { |license| map_from(license) }
                           .sort_by { |license| license[:spdx_identifier] }
              hash[key_for(result)] = licenses if licenses.present?
            end
          end
          strong_memoize_attr :licenses

          def map_from(license)
            return if license[:spdx_identifier] == "unknown"

            license.slice(:name, :spdx_identifier, :url)
          end

          def key_for(result)
            [result.name, result.version, result.purl_type]
          end
        end
      end
    end
  end
end
