# frozen_string_literal: true

module Members
  class AdminRolesFinder < MemberRoles::RolesFinder
    private

    def member_roles
      can_return_admin_roles? ? MemberRole.admin : MemberRole.none
    end
  end
end
