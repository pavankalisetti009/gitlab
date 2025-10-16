# frozen_string_literal: true

module Security
  class PolicyDismissal < ApplicationRecord
    include AfterCommitQueue

    self.table_name = 'security_policy_dismissals'
    DISMISSAL_TYPES = {
      policy_false_positive: 0,
      scanner_false_positive: 1,
      emergency_hot_fix: 2,
      other: 3
    }.freeze

    belongs_to :project, class_name: 'Project', optional: false
    belongs_to :merge_request, class_name: 'MergeRequest', optional: false
    belongs_to :security_policy, class_name: 'Security::Policy', optional: false
    belongs_to :user, class_name: 'User', optional: true

    validates :merge_request_id, uniqueness: { scope: :security_policy_id }
    validates :comment, length: { maximum: 255 }, allow_nil: true
    validate  :dismissal_types_are_valid

    scope :for_projects, ->(project_ids) { where(project_id: project_ids) }
    scope :for_security_findings_uuids, ->(security_findings_uuids) do
      where("security_findings_uuids && ARRAY[?]::text[]", security_findings_uuids)
    end
    scope :pluck_security_findings_uuid, -> { pluck(Arel.sql('DISTINCT unnest(security_findings_uuids)')) } # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- pluck limited to batch size in ee/lib/search/elastic/references/vulnerability.rb#preload_indexing_data
    scope :including_merge_request_and_user, -> { includes(:user, :merge_request) }

    state_machine :status, initial: :open do
      state :open, value: 0
      state :preserved, value: 1

      event :preserve do
        transition any - [:preserved] => :preserved
      end

      after_transition open: :preserved do |dismissal, _|
        next dismissal.destroy! unless dismissal.applicable_for_all_violations?

        dismissal.run_after_commit do
          event = Security::PolicyDismissalPreservedEvent.new(data: { security_policy_dismissal_id: dismissal.id })
          ::Gitlab::EventStore.publish(event)
        end
      end
    end

    def applicable_for_findings?(finding_uuids)
      return false if security_findings_uuids.nil?

      finding_uuids.to_set.subset?(security_findings_uuids.to_set)
    end

    def applicable_for_all_violations?
      applicable_for_findings?(mr_violation_finding_uuids)
    end

    private

    def scan_result_policy_violations
      merge_request.scan_result_policy_violations
                   .joins(:security_policy)
                   .where(security_policies: { id: security_policy_id })
    end

    def mr_violation_finding_uuids
      scan_result_policy_violations.flat_map(&:finding_uuids).uniq
    end

    def dismissal_types_are_valid
      invalid_values = Array(dismissal_types) - DISMISSAL_TYPES.values
      return if dismissal_types.present? && invalid_values.blank?

      errors.add(:dismissal_types, "must be an array with allowed values: #{DISMISSAL_TYPES.values.join(', ')}")
    end
  end
end
