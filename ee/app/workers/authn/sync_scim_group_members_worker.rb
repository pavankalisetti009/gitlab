# frozen_string_literal: true

module Authn
  class SyncScimGroupMembersWorker
    include ApplicationWorker

    feature_category :system_access
    data_consistency :sticky

    idempotent!

    loggable_arguments 0, 1, 2

    # Processes SCIM group membership changes in the background.
    #
    # +scim_group_uid+ - The SCIM group UID to process
    # +user_ids+ - Array of user IDs to add or remove
    # +operation_type+ - Either 'add' or 'remove'
    def perform(scim_group_uid, user_ids, operation_type)
      return unless %w[add remove].include?(operation_type.to_s)

      @scim_group_uid = scim_group_uid

      return if group_links.empty?

      users = User.by_ids(user_ids)
      return if users.empty?

      case operation_type.to_s
      when 'add'
        process_add_members(users)
      when 'remove'
        process_remove_members(users)
      end
    end

    private

    def process_add_members(users)
      grouped_links = group_links.group_by(&:group_id)

      grouped_links.each_value do |links|
        group = links.first.group
        next unless group

        highest_access_level = links.map(&:access_level).max

        users.each do |user|
          existing_member = group.members.by_user_id(user.id).first
          next if existing_member && existing_member.access_level >= highest_access_level

          group.add_member(user, highest_access_level)
        end
      end
    end

    def process_remove_members(users)
      grouped_links = group_links.group_by(&:group_id)

      grouped_links.each do |group_id, links|
        group = links.first.group
        next unless group

        users.each do |user|
          next unless group.member?(user)

          # Use Groups::SyncService to handle removal properly.
          # This preserves memberships that should be maintained.
          ::Groups::SyncService.new(
            group,
            user,
            {
              group_links: [],
              manage_group_ids: [group_id]
            }
          ).execute
        end
      end
    end

    def group_links
      @group_links ||= SamlGroupLink.by_scim_group_uid(@scim_group_uid)
    end
  end
end
