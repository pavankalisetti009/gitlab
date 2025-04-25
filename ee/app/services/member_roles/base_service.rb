# frozen_string_literal: true

module MemberRoles
  class BaseService < ::Authz::CustomRoles::BaseService
    private

    def allowed?
      can?(current_user, :admin_member_role, member_role)
    end

    def group
      params[:namespace] || member_role&.namespace
    end
  end
end
