# frozen_string_literal: true

module Authz
  module AdminRoles
    class CreateService < BaseService
      include Authz::CustomRoles::CreateServiceable

      private

      def build_role
        Authz::AdminRole.new(params)
      end

      def allowed?
        can?(current_user, :create_admin_role)
      end
    end
  end
end
