# frozen_string_literal: true

module Authz
  module AdminRoles
    class BaseService < ::Authz::CustomRoles::BaseService
      private

      def role_class
        Authz::AdminRole
      end
    end
  end
end
