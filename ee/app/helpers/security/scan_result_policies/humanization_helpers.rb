# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module HumanizationHelpers
      def humanized_approval_setting(attribute)
        case attribute
        when :prevent_approval_by_author
          s_("ApprovalSettings|Prevent approval by merge request creator")
        when :prevent_approval_by_commit_author
          s_("ApprovalSettings|Prevent approvals by users who add commits")
        when :require_password_to_approve
          s_("ApprovalSettings|Require user re-authentication (password or SAML) to approve")
        when :remove_approvals_with_new_commit
          "#{s_('ApprovalSettings|When a commit is added:')} #{s_('ApprovalSettings|Remove all approvals')}"
        end
      end
    end
  end
end
