# frozen_string_literal: true

module Authz
  module CustomRoles
    module CreateServiceable
      extend ActiveSupport::Concern

      def execute
        return authorized_error unless allowed?

        role = build_role
        if role.save
          log_audit_event(role, action: :created)

          ::ServiceResponse.success(payload: { member_role: role })
        else

          ::ServiceResponse.error(message: role.errors.full_messages.join(', '))
        end
      end
    end
  end
end
