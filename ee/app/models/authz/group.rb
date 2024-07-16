# frozen_string_literal: true

module Authz
  class Group < Resource
    def initialize(user, scope: user.authorized_groups)
      super(user, scope)
    end

    def permitted
      ::Preloaders::UserMemberRolesInGroupsPreloader
        .new(groups: scope, user: user)
        .execute
    end
  end
end
