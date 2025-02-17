# frozen_string_literal: true

module Resolvers
  module Members
    class AdminRolesResolver < MemberRoles::RolesResolver
      type Types::Members::AdminMemberRoleType, null: true

      private

      def roles_finder
        ::Members::AdminRolesFinder
      end
    end
  end
end
