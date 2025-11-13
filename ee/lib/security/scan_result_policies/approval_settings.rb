# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class ApprovalSettings
      def initialize(approval_settings)
        @approval_settings = approval_settings || {}
      end

      def prevent_approval_by_author
        approval_settings[:prevent_approval_by_author]
      end

      def prevent_approval_by_commit_author
        approval_settings[:prevent_approval_by_commit_author]
      end

      def remove_approvals_with_new_commit
        approval_settings[:remove_approvals_with_new_commit]
      end

      def require_password_to_approve
        approval_settings[:require_password_to_approve]
      end

      def block_branch_modification
        approval_settings[:block_branch_modification]
      end

      def prevent_pushing_and_force_pushing
        approval_settings[:prevent_pushing_and_force_pushing]
      end

      def block_group_branch_modification
        approval_settings[:block_group_branch_modification] || {}
      end

      private

      attr_reader :approval_settings
    end
  end
end
