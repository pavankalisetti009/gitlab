# frozen_string_literal: true

# Security::FindingsFinder
#
# Used to find Ci::Builds associated with requested findings.
#
# Arguments:
#   pipeline - object to filter findings
#   params:
#     severity:    Array<String>
#     confidence:  Array<String>
#     report_type: Array<String>
#     scope:       String
#     limit:       Int

module Security
  class FindingsFinder
    include ::VulnerabilityFindingHelpers

    ResultSet = Struct.new(:relation, :findings) do
      delegate :current_page, :limit_value, :total_pages, :total_count,
        :next_page, :prev_page, :page, :empty?, :without_count, to: :relation
    end

    DEFAULT_LIMIT = 20

    def initialize(pipeline, params: {})
      @pipeline = pipeline
      @params = params
    end

    def execute
      return ResultSet.new(Security::Finding.none, []) unless has_security_findings?

      ResultSet.new(security_findings, findings)
    end

    private

    attr_reader :pipeline, :params

    delegate :project, :has_security_findings?, :security_findings_partition_number, to: :pipeline, private: true

    def findings
      security_findings.map { |finding| build_vulnerability_finding(finding) }
    end

    def report_finding_for(security_finding)
      lookup_uuid = security_finding.overridden_uuid || security_finding.uuid

      report_findings.dig(security_finding.build.id, lookup_uuid)
    end

    def vulnerability_for(finding_uuid)
      existing_vulnerabilities[finding_uuid]
    end

    def existing_vulnerabilities
      @existing_vulnerabilities ||= project.vulnerabilities
               .with_findings_by_uuid(loaded_uuids)
               .index_by(&:finding_uuid)
    end

    def loaded_uuids
      security_findings.map(&:uuid)
    end

    def report_findings
      @report_findings ||= builds.each_with_object({}) do |build, memo|
        reports = build.job_artifacts.map(&:security_report).compact
        next unless reports.present?

        memo[build.id] = reports.flat_map(&:findings).index_by(&:uuid)
      end
    end

    def builds
      security_findings.map(&:build).uniq
    end

    def security_findings
      @security_findings ||= load_security_findings
    end

    def load_security_findings
      # This method generates a query of the general form
      #
      #   SELECT security_findings.*
      #   FROM security_scans
      #   LATERAL (
      #     SELECT * FROM security_findings
      #     LIMIT n
      #   )
      #   WHERE security_scans.x = 'y'
      #   ...
      #
      # This is done for performance reasons to reduce the amount of data loaded
      # in the query compared to a more conventional
      #
      #   SELECT security_findings.*
      #   FROM security_findings
      #   JOIN security_scans ...
      #
      # The latter form can end up reading a very large number of rows on projects
      # with high numbers of findings.
      #
      # Note the inner query needs the LIMIT incremented by 1 because of the
      # way the Kaminari gem implements pagination without total counts.
      # Kaminari increments the LIMIT on the outer relation query by 1 to
      # determine if there are further pages to load. See https://github.com/kaminari/kaminari/blob/13b59ce7ab4e3d0e3072272251de734f918d5f8f/kaminari-activerecord/lib/kaminari/activerecord/active_record_relation_methods.rb#L83-L101

      lateral_relation = Security::Finding
        .where('"security_findings"."scan_id" = "security_scans"."id"') # rubocop:disable CodeReuse/ActiveRecord
        .where('"security_findings"."severity" = "severities"."severity"') # rubocop:disable CodeReuse/ActiveRecord
        .by_partition_number(security_findings_partition_number)
        .deduplicated
        .ordered(params[:sort])
        .then { |relation| by_uuid(relation) }
        .then { |relation| by_confidence_levels(relation) }
        .then { |relation| by_scanner_external_ids(relation) }
        .then { |relation| by_state(relation) }
        .then { |relation| by_include_dismissed(relation) }
        .limit(limit + 1)

      from_sql = <<~SQL.squish
          "security_scans",
          unnest('{#{severities.join(',')}}'::smallint[]) AS "severities" ("severity"),
          LATERAL (#{lateral_relation.to_sql}) AS "security_findings"
      SQL

      Security::Finding
        .from(from_sql) # rubocop:disable CodeReuse/ActiveRecord
        .with_pipeline_entities
        .with_scan
        .with_scanner
        .with_state_transitions
        .with_issue_links
        .with_external_issue_links
        .with_merge_request_links
        .merge(::Security::Scan.by_pipeline_ids(pipeline.id))
        .merge(::Security::Scan.latest_successful)
        .ordered(params[:sort])
        .then { |relation| by_report_types(relation) }
    end

    def limit
      @limit ||= params[:limit] || DEFAULT_LIMIT
    end

    def include_dismissed?
      params[:scope] == 'all' || params[:state]
    end

    def by_include_dismissed(relation)
      return relation if include_dismissed?

      relation.undismissed_by_vulnerability
    end

    def by_scanner_external_ids(relation)
      return relation unless params[:scanner].present?

      relation.by_scanners(project.vulnerability_scanners.with_external_id(params[:scanner]))
    end

    def by_state(relation)
      return relation unless params[:state].present?

      relation.by_state(params[:state])
    end

    def by_confidence_levels(relation)
      return relation unless params[:confidence]

      relation.by_confidence_levels(params[:confidence])
    end

    def by_report_types(relation)
      return relation unless params[:report_type]

      relation.merge(::Security::Scan.by_scan_types(params[:report_type]))
    end

    def by_severity_levels(relation)
      return relation unless params[:severity]

      relation.by_severity_levels(params[:severity])
    end

    def severities
      if params[:severity]
        Security::Finding.severities.fetch_values(*params[:severity])
      else
        Security::Finding.severities.values
      end
    end

    def by_uuid(relation)
      return relation unless params[:uuid]

      relation.by_uuid(params[:uuid])
    end
  end
end
