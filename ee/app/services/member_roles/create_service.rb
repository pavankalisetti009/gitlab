# frozen_string_literal: true

module MemberRoles
  class CreateService < BaseService
    include Authz::CustomRoles::CreateServiceable

    private

    def build_role
      MemberRole.new(params.merge(namespace: group))
    end

    def allowed?
      can?(current_user, :admin_member_role, *[group].compact)
    end
  end
end
