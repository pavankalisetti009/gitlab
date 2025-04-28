# frozen_string_literal: true

module MemberRoles
  class UpdateService < BaseService
    extend ::Gitlab::Utils::Override
    include Authz::CustomRoles::UpdateServiceable

    override :execute
    def execute(member_role)
      @role = member_role

      super
    end

    private

    def allowed?
      can?(current_user, :admin_member_role, role)
    end
  end
end
