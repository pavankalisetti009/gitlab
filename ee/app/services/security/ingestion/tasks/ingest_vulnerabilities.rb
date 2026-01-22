# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestVulnerabilities < AbstractTask
        def execute
          create_new_vulnerabilities
          update_existing_vulnerabilities
          apply_severity_overrides
          mark_resolved_vulnerabilities_as_detected
          create_detection_transitions_for_redetected_vulnerabilities

          finding_maps
        end

        private

        def create_new_vulnerabilities
          IngestVulnerabilities::Create.new(pipeline, partitioned_maps.first).execute
        end

        def update_existing_vulnerabilities
          IngestVulnerabilities::Update.new(pipeline, partitioned_maps.second).execute
          IngestVulnerabilities::SetPresentOnDefaultBranch.new(pipeline, partitioned_maps.second).execute
        end

        def apply_severity_overrides
          IngestVulnerabilities::ApplySeverityOverrides.new(pipeline, partitioned_maps.second).execute
        end

        def mark_resolved_vulnerabilities_as_detected
          IngestVulnerabilities::MarkResolvedAsDetected.execute(pipeline, partitioned_maps.second)
        end

        def create_detection_transitions_for_redetected_vulnerabilities
          return if pipeline.nil?
          return unless Feature.enabled?(:new_security_dashboard_exclude_no_longer_detected, pipeline.project)

          findings = redetected_findings_with_stale_transition
          return if findings.empty?

          ::Vulnerabilities::DetectionTransitions::InsertService.new(findings, detected: true).execute
        end

        def redetected_findings_with_stale_transition
          ::Vulnerabilities::Finding.by_vulnerability_with_stale_detection_transition(vulnerability_ids_not_resolved)
        end

        def vulnerability_ids_not_resolved
          ::Vulnerability
            .with_states(%i[detected confirmed dismissed])
            .id_in(partitioned_maps.second.map(&:vulnerability_id))
            .pluck_primary_key
        end

        def partitioned_maps
          @partitioned_maps ||= finding_maps.partition { |finding_map| finding_map.vulnerability_id.nil? }
        end
      end
    end
  end
end
