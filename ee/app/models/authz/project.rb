# frozen_string_literal: true

module Authz
  class Project < Resource
    def initialize(user, scope: user.authorized_projects)
      super(user, scope)
    end

    def permitted
      ::Preloaders::UserMemberRolesInProjectsPreloader
        .new(projects: scope, user: user)
        .execute
    end
  end
end
