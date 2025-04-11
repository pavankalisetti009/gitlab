# frozen_string_literal: true

module MergeRequests
  class ApprovalRule < ApplicationRecord
    self.table_name = 'merge_requests_approval_rules'

    # If we allow overriding in subgroups there can be multiple groups
    has_many :approval_rules_groups
    has_many :groups, through: :approval_rules_groups

    # When this originated from group there is only one group
    has_one :approval_rules_group, inverse_of: :approval_rule
    has_one :group, through: :approval_rules_group

    # When this originated from group there are multiple projects
    has_many :approval_rules_projects
    has_many :projects, through: :approval_rules_projects

    # When this originated from project there is only one project
    has_one :approval_rules_project
    has_one :project, through: :approval_rules_project

    # When this originated from group or project there are multiple merge_requests
    has_many :approval_rules_merge_requests
    has_many :merge_requests, through: :approval_rules_merge_requests

    # When this originated from merge_request there is only one merge_request
    has_one :approval_rules_merge_request, inverse_of: :approval_rule
    has_one :merge_request, through: :approval_rules_merge_request

    has_many :approval_rules_approver_users
    has_many :approver_users, through: :approval_rules_approver_users, source: :user

    has_many :approval_rules_approver_groups
    has_many :approver_groups, through: :approval_rules_approver_groups, source: :group

    validate :ensure_single_sharding_key

    with_options validate: true do
      enum :rule_type, { regular: 0, code_owner: 1, report_approver: 2, any_approver: 3 }, default: :regular
      enum :origin, { group: 0, project: 1, merge_request: 2 }, prefix: :originates_from
    end

    def approvers
      []
    end

    def from_scan_result_policy?
      false
    end

    def report_type
      nil
    end

    private

    def ensure_single_sharding_key
      return errors.add(:base, "Must have either `group_id` or `project_id`") if no_sharding_key?

      errors.add(:base, "Cannot have both `group_id` and `project_id`") if multiple_sharding_keys?
    end

    def sharding_keys
      [group_id, project_id]
    end

    def no_sharding_key?
      sharding_keys.all?(&:blank?)
    end

    def multiple_sharding_keys?
      sharding_keys.all?(&:present?)
    end
  end
end
