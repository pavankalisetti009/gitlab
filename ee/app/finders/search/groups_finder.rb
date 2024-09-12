# frozen_string_literal: true

# Finder for retrieving authorized groups to use for search
# This finder returns all groups that a user has authorization to because:
# 1. They are direct members of the group
# 2. They are direct members of a group that is invited to the group
#
# This finder does not take into account a group's sub-groups, descendants, or ancestors
module Search
  class GroupsFinder
    include Gitlab::Utils::StrongMemoize

    # user - The currently logged in user, if any.
    # params - Placeholder for future finder params
    def initialize(user:, _params: {})
      @user = user
    end

    # rubocop:disable CodeReuse/ActiveRecord -- This is a custom finder
    def execute
      return Group.none unless user

      Group.unscoped do
        Group.from_union([direct_groups, linked_groups])
      end
    end
    # rubocop:enable CodeReuse/ActiveRecord

    private

    attr_reader :user

    def direct_group_membership_source_ids
      user.group_members.active.select(:source_id)
    end

    def direct_groups
      Group.id_in(direct_group_membership_source_ids)
    end

    def linked_groups
      group_links = GroupGroupLink.for_shared_with_groups(direct_group_membership_source_ids).not_expired
      Group.id_in(group_links.select(:shared_group_id))
    end
  end
end
