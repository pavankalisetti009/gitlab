# frozen_string_literal: true

module MemberRoles
  class BaseService < ::Authz::CustomRoles::BaseService
    private

    def role_class
      MemberRole
    end

    def allowed?
      can?(current_user, :admin_member_role, role)
    end

    def group
      params[:namespace] || role&.namespace
    end
  end
end
