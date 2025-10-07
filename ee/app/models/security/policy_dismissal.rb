# frozen_string_literal: true

module Security
  class PolicyDismissal < ApplicationRecord
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

    private

    def dismissal_types_are_valid
      invalid_values = Array(dismissal_types) - DISMISSAL_TYPES.values
      return if dismissal_types.present? && invalid_values.blank?

      errors.add(:dismissal_types, "must be an array with allowed values: #{DISMISSAL_TYPES.values.join(', ')}")
    end
  end
end
