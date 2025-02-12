# frozen_string_literal: true

module MergeRequests
  class ApprovalRulesMergeRequest < ApplicationRecord
    self.table_name = 'merge_requests_approval_rules_merge_requests'

    belongs_to :approval_rule, class_name: 'MergeRequests::ApprovalRule'
    belongs_to :merge_request, class_name: 'MergeRequest'

    validates :merge_request_id, uniqueness: { scope: :approval_rule_id }
    before_create :set_project_id

    private

    def set_project_id
      self.project_id = merge_request.source_project.id
    end
  end
end
