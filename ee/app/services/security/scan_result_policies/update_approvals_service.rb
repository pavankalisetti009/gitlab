# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateApprovalsService
      include Gitlab::Utils::StrongMemoize
      include VulnerabilityStatesHelper
      include ::Security::ScanResultPolicies::PolicyLogger
      include ::Security::ScanResultPolicies::RelatedPipelines

      ViolationResult = Struct.new(:violated, :newly_detected, :previously_existing, keyword_init: true)

      attr_reader :pipeline, :merge_request

      def initialize(merge_request:, pipeline:)
        @pipeline = pipeline
        @merge_request = merge_request
      end

      def execute
        unless pipeline_with_security_reports_exists?
          log_update_approval_rule('No security reports found for the pipeline', **validation_context)
          return
        end

        approval_rules = merge_request.approval_rules.scan_finding
        approval_rules_with_newly_detected_states = filter_newly_detected_rules(:scan_finding, approval_rules)
        return if approval_rules_with_newly_detected_states.empty?

        evaluate_rules(approval_rules_with_newly_detected_states)
        evaluation.save
      end

      def scan_missing?(approval_rule)
        target_scans_missing_in_source(approval_rule).any? || missing_target_scans(approval_rule).any?
      end

      private

      def pipeline_with_security_reports_exists?
        # First check if our pipeline has reports before looking up related pipelines
        return true if pipeline.can_store_security_reports?

        related_pipeline_with_security_reports_exists?
      end

      def related_pipeline_with_security_reports_exists?
        related_pipelines(pipeline).with_reports(::Ci::JobArtifact.security_reports).exists?
      end

      def validation_context(approval_rule = nil)
        if approval_rule
          { pipeline_ids: related_source_pipeline_ids, target_pipeline_ids: related_target_pipeline_ids(approval_rule) }
        else
          { pipeline_ids: related_source_pipeline_ids }
        end
      end

      delegate :project, to: :pipeline

      def evaluate_rules(approval_rules)
        log_update_approval_rule('Evaluating scan_finding rules from approval policies', **validation_context)

        approval_rules.each do |merge_request_approval_rule|
          next if enforce_scans_presence!(merge_request_approval_rule)

          approval_rule = merge_request_approval_rule.try(:source_rule) || merge_request_approval_rule
          violation_result = violates_approval_rule?(approval_rule)

          if violation_result.violated
            log_update_approval_rule(
              'Updating MR approval rule',
              reason: 'scan_finding rule violated',
              approval_rule_id: merge_request_approval_rule.id,
              approval_rule_name: merge_request_approval_rule.name
            )
            fail_evaluation_with_data!(merge_request_approval_rule,
              newly_detected: violation_result.newly_detected,
              previously_existing: violation_result.previously_existing
            )
          else
            evaluation.pass!(merge_request_approval_rule)
          end
        end
      end

      def enforce_scans_presence!(approval_rule)
        source_scans_diff = target_scans_missing_in_source(approval_rule)
        if source_scans_diff.any?
          handle_scanner_mismatch_error(
            approval_rule, :scan_removed, 'Scanner removed by MR', source_scans_diff
          )
          return true
        end

        target_scans_diff = missing_target_scans(approval_rule)
        if target_scans_diff.any?
          handle_scanner_mismatch_error(
            approval_rule, :target_scan_missing, 'Enforced scanner missing on target branch', target_scans_diff
          )
          return true
        end

        false
      end

      def handle_scanner_mismatch_error(approval_rule, reason, reason_msg, missing_scans)
        unless fail_open?(approval_rule)
          log_update_approval_rule(
            'Updating MR approval rule',
            reason: reason_msg,
            approval_rule_id: approval_rule.id,
            approval_rule_name: approval_rule.name,
            missing_scans: missing_scans
          )
        end

        evaluation.error!(
          approval_rule, reason, context: validation_context(approval_rule), missing_scans: missing_scans
        )
      end

      def log_update_approval_rule(message, **attributes)
        log_policy_evaluation('update_approvals', message,
          project: project, merge_request_id: merge_request.id, merge_request_iid: merge_request.iid, **attributes)
      end

      def violates_approval_rule?(approval_rule)
        pipeline_uuids = pipeline_findings_uuids(approval_rule)

        return ViolationResult.new(violated: false) if only_newly_detected?(approval_rule) && pipeline_uuids.empty?

        violates_vulnerabilities_allowed?(approval_rule, pipeline_uuids)
      end

      def violates_vulnerabilities_allowed?(approval_rule, pipeline_uuids)
        vulnerabilities_allowed = approval_rule.vulnerabilities_allowed
        target_pipeline_uuids = target_pipeline_findings_uuids(approval_rule)
        new_uuids = pipeline_uuids - target_pipeline_uuids

        if only_newly_detected?(approval_rule)
          violated = new_uuids.count > vulnerabilities_allowed
          return ViolationResult.new(violated: violated, newly_detected: new_uuids)
        end

        vulnerabilities_count = vulnerabilities_count_for_uuids(pipeline_uuids + target_pipeline_uuids, approval_rule)
        previously_existing_uuids = (pipeline_uuids + target_pipeline_uuids - new_uuids).uniq

        if vulnerabilities_count[:exceeded_allowed_count]
          return ViolationResult.new(
            violated: true, newly_detected: new_uuids, previously_existing: previously_existing_uuids
          )
        end

        total_count = vulnerabilities_count[:count]
        total_count += new_uuids.count if include_newly_detected?(approval_rule)

        violated = total_count > vulnerabilities_allowed
        ViolationResult.new(
          violated: violated, newly_detected: new_uuids, previously_existing: previously_existing_uuids
        )
      end

      def target_scans_missing_in_source(approval_rule)
        scanners = approval_rule.scanners_with_default_fallback
        # No target pipeline, report specified scanners that are not on the source branch as missing
        return (scanners - pipeline_security_scan_types) unless target_pipeline(approval_rule)

        # Target pipeline has scans, but some may be missing on the source branch
        scan_types_diff = target_pipeline_security_scan_types(approval_rule) - pipeline_security_scan_types
        # Return the diff for specified scanners
        scan_types_diff & scanners
      end

      def missing_target_scans(approval_rule)
        return [] if ::Feature.disabled?(:approval_policies_enforce_target_scans, project)

        scanners = approval_rule.scanners_with_default_fallback
        scanners - target_pipeline_security_scan_types(approval_rule)
      end

      def pipeline_security_scan_types
        security_scan_types(related_source_pipeline_ids)
      end
      strong_memoize_attr :pipeline_security_scan_types

      def target_pipeline_security_scan_types(approval_rule)
        strong_memoize_with(:target_pipeline_security_scan_types, approval_rule) do
          security_scan_types(related_target_pipeline_ids(approval_rule))
        end
      end

      def fail_evaluation_with_data!(rule, newly_detected: nil, previously_existing: nil)
        evaluation.fail!(
          rule,
          data: {
            uuids: {
              newly_detected: Security::ScanResultPolicyViolation.trim_violations(newly_detected),
              previously_existing: Security::ScanResultPolicyViolation.trim_violations(previously_existing)
            }.compact_blank
          },
          context: validation_context(rule)
        )
      end

      def evaluation
        @evaluation ||= Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService.new(merge_request)
      end

      def security_scan_types(pipeline_ids)
        Security::Scan.by_pipeline_ids(pipeline_ids).distinct_scan_types
      end

      def target_pipeline(approval_rule)
        strong_memoize_with(:target_pipeline, approval_rule) do
          target_pipeline_for_merge_request(merge_request, :scan_finding, approval_rule)
        end
      end

      def related_target_pipeline_ids(approval_rule)
        strong_memoize_with(:related_target_pipeline_ids, approval_rule) do
          related_target_pipeline_ids_for_merge_request(merge_request, :scan_finding, approval_rule)
        end
      end

      def related_source_pipeline_ids
        related_pipeline_ids(pipeline)
      end
      strong_memoize_attr :related_source_pipeline_ids

      def target_pipeline_findings_uuids(approval_rule)
        findings_uuids(target_pipeline(approval_rule), approval_rule, related_target_pipeline_ids(approval_rule))
      end

      def pipeline_findings_uuids(approval_rule)
        findings_uuids(pipeline, approval_rule, related_source_pipeline_ids, true)
      end

      def findings_uuids(pipeline, approval_rule, pipeline_ids, check_dismissed = false)
        finder_params = {
          vulnerability_states: approval_rule.vulnerability_states_for_branch,
          severity_levels: approval_rule.severity_levels,
          scanners: approval_rule.scanners,
          fix_available: approval_rule.vulnerability_attribute_fix_available,
          false_positive: approval_rule.vulnerability_attribute_false_positive,
          check_dismissed: check_dismissed
        }

        finder_params[:related_pipeline_ids] = pipeline_ids if pipeline_ids.present?

        Security::ScanResultPolicies::FindingsFinder
          .new(project, pipeline, finder_params)
          .execute
          .distinct_uuids
      end

      def vulnerabilities_count_for_uuids(uuids, approval_rule)
        VulnerabilitiesCountService.new(
          project: project,
          uuids: uuids,
          states: states_without_newly_detected(approval_rule.vulnerability_states_for_branch),
          allowed_count: approval_rule.vulnerabilities_allowed,
          vulnerability_age: approval_rule.scan_result_policy_read&.vulnerability_age
        ).execute
      end

      def fail_open?(approval_rule)
        approval_rule.scan_result_policy_read&.fail_open?
      end
    end
  end
end
