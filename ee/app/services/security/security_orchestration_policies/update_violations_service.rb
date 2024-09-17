# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdateViolationsService
      attr_reader :merge_request, :violated_policy_ids, :unviolated_policy_ids, :violation_data, :report_type

      delegate :project, to: :merge_request

      def initialize(merge_request, report_type)
        @merge_request = merge_request
        @violated_policy_ids = Set.new
        @unviolated_policy_ids = Set.new
        @violation_data = {}
        @report_type = report_type
      end

      def add(violated_ids, unviolated_ids)
        violated_policy_ids.merge(violated_ids.compact)
        unviolated_policy_ids.merge(unviolated_ids.compact)
      end

      def add_violation(policy_id, data, context: nil)
        add([policy_id], [])

        @violation_data[policy_id] ||= {}
        @violation_data[policy_id].deep_merge!({ context: context, violations: { report_type => data } }.compact_blank)
      end

      def add_error(policy_id, error, **extra_data)
        add([policy_id], [])

        violation_data[policy_id] ||= {}
        violation_data[policy_id][:errors] ||= []
        violation_data[policy_id][:errors] << {
          error: Security::ScanResultPolicyViolation::ERRORS[error],
          **extra_data
        }
      end

      def execute
        Security::ScanResultPolicyViolation.transaction do
          delete_violations if unviolated_policy_ids.any?
          create_violations if violated_policy_ids.any?
        end

        [violated_policy_ids.clear, unviolated_policy_ids.clear]
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def delete_violations
        Security::ScanResultPolicyViolation
          .where(merge_request_id: merge_request.id, scan_result_policy_id: unviolated_policy_ids)
          .each_batch(order_hint: :updated_at) { |batch| batch.delete_all }
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def create_violations
        attrs = violated_policy_ids.map do |id|
          { scan_result_policy_id: id, merge_request_id: merge_request.id, project_id: merge_request.project_id,
            violation_data: violation_data[id], status: ScanResultPolicyViolation.statuses[:completed] }
        end
        return unless attrs.any?

        Security::ScanResultPolicyViolation.upsert_all(attrs, unique_by: %w[scan_result_policy_id merge_request_id])
      end
    end
  end
end
