# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyBypassAuditor
      def initialize(security_policy:, project:, user:, branch_name:)
        @security_policy = security_policy
        @project = project
        @user = user
        @branch_name = branch_name
      end

      def log_access_token_bypass(token_ids)
        audit_details = build_access_token_audit_details(token_ids)
        log_bypass_event(:access_token, token_ids, audit_details)
      end

      def log_service_account_bypass(service_account_id)
        audit_details = build_service_account_audit_details(service_account_id)
        log_bypass_event(:service_account, service_account_id, audit_details)
      end

      def log_user_bypass(user_bypass_scope, reason)
        audit_details = build_user_audit_details(user_bypass_scope, reason)
        log_bypass_event(:user, user.id, audit_details, reason)
      end

      private

      attr_reader :security_policy, :project, :user, :branch_name

      def log_bypass_event(bypass_type, identifier, additional_details, reason = nil)
        message = bypass_audit_message(bypass_type, identifier, reason)

        Gitlab::Audit::Auditor.audit(
          name: "security_policy_#{bypass_type}_push_bypass",
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: message,
          additional_details: {
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: branch_name
          }.merge(additional_details)
        )
      end

      def build_access_token_audit_details(token_ids)
        {
          bypass_type: :access_token,
          access_token_ids: token_ids
        }
      end

      def build_service_account_audit_details(service_account_id)
        {
          bypass_type: :service_account,
          service_account_id: service_account_id
        }
      end

      def build_user_audit_details(user_bypass_scope, reason)
        {
          user_id: user.id,
          reason: reason,
          bypass_type: user_bypass_scope
        }.merge(bypass_scope_details(user_bypass_scope))
      end

      def bypass_scope_details(user_bypass_scope)
        case user_bypass_scope
        when :group
          { group_ids: security_policy.bypass_settings.group_ids }
        when :role
          {
            default_roles: security_policy.bypass_settings.default_roles,
            custom_role_ids: security_policy.bypass_settings.custom_role_ids
          }
        else
          {}
        end
      end

      def bypass_audit_message(type, identifier, reason = nil)
        message = <<~MSG.squish
          Branch push restriction on '#{branch_name}' for project '#{project.full_path}'
          has been bypassed by #{type} with ID: #{identifier}
        MSG

        message += " with reason: #{reason}" if reason.present?
        message
      end
    end
  end
end
