# frozen_string_literal: true

module Authz
  module AdminRoles
    class UpdateService < BaseService
      extend ::Gitlab::Utils::Override
      include Authz::CustomRoles::UpdateServiceable

      override :execute
      def execute(admin_role)
        @role = admin_role

        super
      end

      private

      def allowed?
        can?(current_user, :update_admin_role, role)
      end
    end
  end
end
