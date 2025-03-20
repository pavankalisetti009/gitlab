# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module PolicyViolationCommentGenerator
      private

      def generate_policy_bot_comment(merge_request)
        return if bot_message_disabled?(merge_request)
        return unless violations_populated?(merge_request)

        Security::GeneratePolicyViolationCommentWorker.perform_async(merge_request.id)
      end

      def violations_populated?(merge_request)
        !merge_request.scan_result_policy_violations.without_violation_data.exists?
      end

      def bot_message_disabled?(merge_request)
        project = merge_request.project

        return true if project.archived?

        security_policy_ids = merge_request.approval_rules.report_approver
                                           .applicable_to_branch(merge_request.target_branch)
                                           .filter_map(&:scan_result_policy_id)
        return false if security_policy_ids.blank?

        policies = project.scan_result_policy_reads.id_in(security_policy_ids)
        return false if policies.blank?

        policies.all?(&:bot_message_disabled?)
      end
    end
  end
end
