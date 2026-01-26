# frozen_string_literal: true

# Finder for retrieving authorized projects to use for search
# This finder returns all projects that a user has authorization to because:
# 1. They are direct members of the project
# 2. They are a direct member of a group and the project gets shared with that group
# 3. They are a direct member of a group and the project gets shared with a group in the descendent hierarchy
module Search
  class ProjectsFinder
    include Gitlab::Utils::StrongMemoize

    # user - The currently logged in user, if any.
    # params - Placeholder for future finder params
    def initialize(user:, _params: {})
      @user = user
    end

    def execute
      return Project.none unless user

      Project.unscoped do
        Project
          .from_union([
            direct_projects,
            linked_through_group_projects
          ])
      end
    end

    private

    attr_reader :user

    def group_membership_source_ids
      user.authorized_groups(include_project_authorizations: false).select(:id)
    end

    def project_membership_source_ids
      user.project_members.active.select(:source_id)
    end

    def direct_projects
      Project.id_in(project_membership_source_ids)
    end

    def linked_through_group_projects
      links = ProjectGroupLink.in_group(group_membership_source_ids).not_expired
      Project.id_in(links.select(:project_id))
    end
  end
end
