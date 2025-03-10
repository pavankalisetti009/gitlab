# frozen_string_literal: true

module MemberRoles
  class CreateService < BaseService
    include ::GitlabSubscriptions::SubscriptionHelper

    def execute
      return authorized_error unless allowed?

      role = MemberRole.new(params.merge(namespace: group))
      if role.save
        log_audit_event(role, action: :created)

        ::ServiceResponse.success(payload: { member_role: role })
      else
        ::ServiceResponse.error(message: role.errors.full_messages.join(', '))
      end
    end

    private

    def allowed?
      can?(current_user, :admin_member_role, *[group].compact)
    end
  end
end
