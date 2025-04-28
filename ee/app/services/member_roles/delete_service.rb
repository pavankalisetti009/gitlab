# frozen_string_literal: true

module MemberRoles
  class DeleteService < BaseService
    def execute(member_role)
      @role = member_role

      return authorized_error unless allowed?

      if role.dependent_security_policies.exists?
        return ::ServiceResponse.error(
          message: 'Custom role linked with a security policy.',
          payload: { member_role: role }
        )
      end

      if role.destroy
        log_audit_event(role, action: :deleted)

        ::ServiceResponse.success(payload: {
          member_role: role
        })
      else
        ::ServiceResponse.error(
          message: role.errors.full_messages,
          payload: { member_role: role }
        )
      end
    end
  end
end
