# frozen_string_literal: true

module Security
  class PolicyDismissal < ApplicationRecord
    self.table_name = 'security_policy_dismissals'

    belongs_to :project, class_name: 'Project', optional: false
    belongs_to :merge_request, class_name: 'MergeRequest', optional: false
    belongs_to :security_policy, class_name: 'Security::Policy', optional: false
    belongs_to :user, class_name: 'User', optional: true

    validates :merge_request_id, uniqueness: { scope: :security_policy_id }
    validates :security_findings_uuids, presence: true
  end
end
