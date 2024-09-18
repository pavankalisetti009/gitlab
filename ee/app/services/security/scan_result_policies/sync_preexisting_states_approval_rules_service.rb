# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class SyncPreexistingStatesApprovalRulesService
      include PolicyViolationCommentGenerator
      include VulnerabilityStatesHelper

      def initialize(merge_request)
        @merge_request = merge_request
        @violations = Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request, :scan_finding)
      end

      def execute
        return if merge_request.merged?

        sync_required_approvals
      end

      private

      attr_reader :merge_request, :violations

      delegate :project, to: :merge_request, private: true

      def sync_required_approvals
        all_scan_finding_rules = merge_request.approval_rules.scan_finding.including_scan_result_policy_read
        rules_with_preexisting_states = all_scan_finding_rules.reject do |rule|
          include_newly_detected?(rule)
        end

        return unless rules_with_preexisting_states.any?

        update_scan_finding_rules_with_preexisting_states(rules_with_preexisting_states)
        generate_policy_bot_comment(merge_request, all_scan_finding_rules, :scan_finding)
      end

      def update_scan_finding_rules_with_preexisting_states(approval_rules)
        violated_rules, unviolated_rules = approval_rules.partition do |rule|
          preexisting_findings_count_violated?(rule)
        end
        update_required_approvals(violated_rules, unviolated_rules)
      end

      def update_required_approvals(violated_rules, unviolated_rules)
        merge_request.reset_required_approvals(violated_rules)
        ApprovalMergeRequestRule.remove_required_approved(unviolated_rules) if unviolated_rules.any?

        log_violated_rules(violated_rules)
        violations.add(violated_rules.map(&:scan_result_policy_read), unviolated_rules)
        violations.execute
      end

      def preexisting_findings_count_violated?(approval_rule)
        vulnerabilities = vulnerabilities(approval_rule)

        violated = vulnerabilities.count > approval_rule.vulnerabilities_allowed
        save_violations(approval_rule, vulnerabilities) if violated
        violated
      end

      def vulnerabilities(approval_rule)
        finder_params = {
          limit: approval_rule.vulnerabilities_allowed + 1,
          state: states_without_newly_detected(approval_rule.vulnerability_states_for_branch),
          severity: approval_rule.severity_levels,
          report_type: approval_rule.scanners,
          fix_available: approval_rule.vulnerability_attribute_fix_available,
          false_positive: approval_rule.vulnerability_attribute_false_positive,
          vulnerability_age: approval_rule.scan_result_policy_read&.vulnerability_age
        }
        ::Security::ScanResultPolicies::VulnerabilitiesFinder.new(project, finder_params).execute
      end

      def log_violated_rules(rules)
        return unless rules.any?

        rules.each do |approval_rule|
          log_violated_rule(
            approval_rule_id: approval_rule.id,
            approval_rule_name: approval_rule.name
          )
        end
      end

      def log_violated_rule(**attributes)
        default_attributes = {
          reason: 'pre_existing scan_finding_rule violated',
          event: 'update_approvals',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_path: merge_request.project.full_path
        }
        Gitlab::AppJsonLogger.info(
          message: 'Updating MR approval rule with pre_existing states',
          **default_attributes.merge(attributes)
        )
      end

      def save_violations(approval_rule, vulnerabilities)
        violated_uuids = vulnerabilities.with_findings
                                        .limit(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)
                                        .map(&:finding_uuid)
        violations.add_violation(approval_rule.scan_result_policy_read, {
          uuids: { previously_existing: violated_uuids }
        })
      end
    end
  end
end
