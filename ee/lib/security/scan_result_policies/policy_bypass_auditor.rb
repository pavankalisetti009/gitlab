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

      def log_merge_request_bypass(merge_request, security_policy, reason)
        audit_details = build_merge_request_audit_details(merge_request, security_policy, reason)
        log_bypass_event(:merge_request, security_policy, audit_details, reason, merge_request)
      end

      private

      attr_reader :security_policy, :project, :user, :branch_name

      def log_bypass_event(bypass_type, identifier, additional_details, reason = nil, merge_request = nil)
        message = build_audit_message(bypass_type, identifier, reason, merge_request)
        audit_name = audit_name_for_bypass_type(bypass_type)

        Gitlab::Audit::Auditor.audit(
          name: audit_name,
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

      def build_merge_request_audit_details(merge_request, security_policy, reason)
        {
          bypass_type: :merge_request,
          security_policy_id: security_policy.id,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          security_policy_name: security_policy.name,
          reason: reason
        }
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

      def audit_name_for_bypass_type(bypass_type)
        case bypass_type
        when :merge_request
          'security_policy_merge_request_bypass'
        else
          "security_policy_#{bypass_type}_push_bypass"
        end
      end

      def build_audit_message(bypass_type, identifier, reason, merge_request)
        message = case bypass_type
                  when :merge_request
                    merge_request_audit_message(identifier, merge_request)
                  else
                    bypass_audit_message(bypass_type, identifier)
                  end
        message += " with reason: #{reason}" if reason.present?
        message
      end

      def merge_request_audit_message(security_policy, merge_request)
        <<~MSG.squish
          Security policy #{security_policy.name} in merge request
          (#{project.full_path}!#{merge_request.iid}) has been bypassed by #{user.name}
        MSG
      end

      def bypass_audit_message(type, identifier)
        <<~MSG.squish
          Branch push restriction on '#{branch_name}' for project '#{project.full_path}'
          has been bypassed by #{type} with ID: #{identifier}
        MSG
      end
    end
  end
end
