# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyBypassChecker
      include Gitlab::Utils::StrongMemoize

      BypassReasonRequiredError = Class.new(StandardError)

      def initialize(security_policy:, project:, user_access:, branch_name:, push_options:)
        @security_policy = security_policy
        @project = project
        @user = user_access.user
        @branch_name = branch_name
        @push_options = push_options
      end

      def bypass_allowed?
        return false unless user

        bypass_with_access_token? || bypass_with_service_account? || bypass_with_user?
      end

      private

      attr_reader :security_policy, :project, :user, :branch_name, :push_options

      def audit_logger
        PolicyBypassAuditor.new(
          security_policy: security_policy,
          project: project,
          user: user,
          branch_name: branch_name
        )
      end
      strong_memoize_attr :audit_logger

      def bypass_with_access_token?
        policy_token_ids = security_policy.bypass_settings.access_token_ids
        return false if policy_token_ids.blank?

        return false unless user.project_bot?

        user_token_ids = user.personal_access_tokens.active.id_in(policy_token_ids).pluck_primary_key
        return false if user_token_ids.blank?

        audit_logger.log_access_token_bypass(user_token_ids)
        true
      end

      def bypass_with_service_account?
        policy_service_account_ids = security_policy.bypass_settings.service_account_ids
        return false if policy_service_account_ids.blank?

        return false unless user.service_account?
        return false unless policy_service_account_ids.include?(user.id)

        audit_logger.log_service_account_bypass(user.id)
        true
      end

      def bypass_with_user?
        user_bypass_scope = UserBypassChecker.new(
          security_policy: security_policy, project: project, current_user: user
        ).bypass_scope

        return false unless user_bypass_scope

        reason = reason_from_push_options
        raise BypassReasonRequiredError, "Bypass reason is required for user bypass" if reason.blank?

        audit_logger.log_user_bypass(user_bypass_scope, reason)
        true
      end

      def reason_from_push_options
        return if push_options.nil?

        reason = push_options.get(:security_policy)&.dig(:bypass_reason)

        Sanitize.clean(reason) if reason.present?
      end
      strong_memoize_attr :reason_from_push_options
    end
  end
end
