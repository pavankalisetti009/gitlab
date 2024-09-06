# frozen_string_literal: true

module Namespaces
  module Export
    class GroupMembersTypeCombinator
      attr_reader :group

      def initialize(group)
        @group = group
      end

      def execute(group_members, inherited_members)
        # first we select only the members who are really direct
        # in group_members we will have only shared members remained
        direct_members = group_members.extract! { |member| direct_member?(member) }
        direct_user_ids = direct_members.map(&:user_id)

        indirect_members = []
        overridden_shared_members = []

        inherited_members.each do |inherited_member|
          shared_member = shared_membership_for(inherited_member, group_members)
          type = membership_type(inherited_member, shared_member, direct_user_ids, group_members)

          next if type == :direct

          overridden_shared_members << shared_member if type == :shared
          indirect_members << inherited_member
        end

        shared_members = group_members - overridden_shared_members

        # we return combination of direct, inherited and shared members
        direct_members + indirect_members + shared_members
      end

      private

      def shared_membership_for(member, group_members)
        group_members.find { |m| m.user_id == member.user_id }
      end

      def membership_type(member, shared_member, direct_user_ids, group_members)
        return :direct if direct_user_ids.include?(member.user_id)

        return :indirect if group_members.blank? # we can skip if we don't have any further group members

        return :indirect unless shared_member

        return :direct if member.access_level < shared_member.access_level

        :shared
      end

      def direct_member?(member)
        member.source_id == group.id
      end
    end
  end
end
