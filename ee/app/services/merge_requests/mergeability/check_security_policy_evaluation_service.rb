# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckSecurityPolicyEvaluationService < CheckBaseService
      identifier :security_policy_evaluation
      description 'Checks whether the security policies are evaluated'

      def execute
        if ::Feature.disabled?(:policy_mergability_check,
          merge_request.project) || merge_request.scan_result_policy_reads_through_approval_rules.none?
          return inactive
        end

        if merge_request.running_scan_result_policy_violations.any?
          failure
        else
          success
        end
      end

      def skip?
        params[:skip_security_policy_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
