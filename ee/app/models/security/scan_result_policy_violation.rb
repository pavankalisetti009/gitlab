# frozen_string_literal: true

module Security
  class ScanResultPolicyViolation < ApplicationRecord
    include EachBatch

    belongs_to :project, inverse_of: :scan_result_policy_violations
    belongs_to :scan_result_policy_read,
      class_name: 'Security::ScanResultPolicyRead',
      foreign_key: 'scan_result_policy_id',
      inverse_of: :violations

    belongs_to :merge_request, inverse_of: :scan_result_policy_violations
    belongs_to :approval_policy_rule, class_name: 'Security::ApprovalPolicyRule', inverse_of: :violations
    has_one :security_policy, class_name: 'Security::Policy', through: :approval_policy_rule

    validates :scan_result_policy_id, uniqueness: { scope: %i[merge_request_id] }
    validates :violation_data, json_schema: { filename: 'scan_result_policy_violation_data' }, allow_blank: true

    scope :running, -> { where(status: :running) }
    scope :for_security_policies, ->(security_policies) {
      left_outer_joins(:approval_policy_rule).where(approval_policy_rule: { security_policy: security_policies })
    }
    scope :group_by_security_policy_id, -> {
      includes(:approval_policy_rule).group_by do |v|
        v.approval_policy_rule&.security_policy_id
      end
    }

    enum :status, {
      running: 0,
      failed: 1,
      warn: 2,
      skipped: 3
    }

    scope :including_scan_result_policy_reads, -> { includes(:scan_result_policy_read) }
    scope :including_security_policies, -> { includes(:security_policy) }
    scope :for_merge_request, ->(merge_request) { where(merge_request: merge_request) }

    scope :for_approval_rules,
      ->(approval_rules) {
        where(scan_result_policy_id: approval_rules.pluck(:scan_result_policy_id))
      }

    scope :without_violation_data, -> { where(violation_data: nil) }
    scope :with_violation_data, -> { where.not(violation_data: nil) }

    scope :with_security_policy_dismissal, -> {
      joins(security_policy: :policy_dismissals)
        .includes(security_policy: :policy_dismissals)
        .where('security_policy_dismissals.merge_request_id = scan_result_policy_violations.merge_request_id')
    }

    ERRORS = {
      scan_removed: 'SCAN_REMOVED',
      target_scan_missing: 'TARGET_SCAN_MISSING',
      target_pipeline_missing: 'TARGET_PIPELINE_MISSING',
      artifacts_missing: 'ARTIFACTS_MISSING',
      evaluation_skipped: 'EVALUATION_SKIPPED',
      pipeline_failed: 'PIPELINE_FAILED'
    }.freeze

    MAX_VIOLATIONS = 10
    FINDING_STATES = %w[previously_existing newly_detected].freeze

    def self.trim_violations(violations)
      Array.wrap(violations)[..MAX_VIOLATIONS]
    end

    def finding_uuids
      FINDING_STATES.flat_map do |key|
        violation_data&.dig("violations", "scan_finding", "uuids", key)
      end.compact_blank
    end

    def dismissed?
      return false if security_policy.nil?

      dismissal = if association(:security_policy).loaded? && security_policy.association(:policy_dismissals).loaded?
                    security_policy.policy_dismissals.find { |d| d.merge_request_id == merge_request_id }
                  else
                    Security::PolicyDismissal.find_by(
                      security_policy: security_policy,
                      merge_request: merge_request
                    )
                  end

      return false unless dismissal

      dismissal.applicable_for_findings?(finding_uuids)
    end
  end
end
