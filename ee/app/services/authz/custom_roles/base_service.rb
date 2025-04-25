# frozen_string_literal: true

module Authz
  module CustomRoles
    class BaseService < ::BaseService
      include Gitlab::Allowable

      attr_accessor :current_user, :params, :member_role

      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params
      end

      private

      def authorized_error
        ::ServiceResponse.error(message: _('Operation not allowed'), reason: :unauthorized)
      end

      def log_audit_event(role, action:)
        audit_context = {
          author: current_user,
          target: role,
          target_details: {
            name: role.name,
            description: role.description,
            abilities: role.enabled_permissions(current_user).keys.join(', ')
          },
          **audit_event_attributes(role, action)
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def audit_event_attributes(role, action)
        if role.admin_related_role?
          {
            name: "admin_role_#{action}",
            scope: Gitlab::Audit::InstanceScope.new,
            message: "Admin role was #{action}"
          }
        else
          {
            name: "member_role_#{action}",
            scope: group || Gitlab::Audit::InstanceScope.new,
            message: "Member role was #{action}"
          }
        end
      end
    end
  end
end
