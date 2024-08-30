# frozen_string_literal: true

module Namespaces
  module Export
    class GroupMembershipCollector
      attr_reader :result, :target_group_ancestor_ids, :members, :target_group, :current_user

      def initialize(target_group, current_user)
        @result = []
        @members = {}

        @current_user = current_user
        @target_group = target_group
        @target_group_ancestor_ids = target_group.ancestor_ids
      end

      def execute
        cursor = { current_id: target_group.id, depth: [target_group.id] }
        iterator = Gitlab::Database::NamespaceEachBatch.new(namespace_class: Group, cursor: cursor)

        iterator.each_batch(of: 100) do |ids|
          groups = Group.id_in(ids).in_order_of(:id, ids)

          groups.each do |group|
            process_group(group)
          end
        end

        order
      end

      private

      def order
        result.sort_by { |member| [member.group_id, member.membership_type, member.username] }
      end

      def process_group(group)
        group_memberships = memberships_for_group(group)
        group_parent = group.parent_id unless target_group == group

        update_parent_groups(group_parent) unless group == target_group

        all_group_members = if target_group == group
                              group_memberships
                            else
                              GroupMembersTypeCombinator.new(group)
                                .execute(group_memberships.to_a, members[group_parent])
                            end

        result.concat(transform_data(all_group_members, group))

        target_group_ancestor_ids << group.id
        members[group.id] = all_group_members
      end

      def memberships_for_group(group)
        # for all groups we retrieve direct and shared members, inherited will be calculated from the ancestors
        relations = [:direct, :shared_from_groups]

        # for root group we have to retrieve also inherited members as there is no ancestor to calculate them from
        relations << :inherited if group == target_group

        GroupMembersFinder.new(group, current_user).execute(include_relations: relations)
          .including_source.including_user
      end

      def update_parent_groups(group_parent)
        return if target_group_ancestor_ids.empty?
        return if group_parent == target_group_ancestor_ids.last

        parent_index = target_group_ancestor_ids.find_index(group_parent)
        count_to_remove = target_group_ancestor_ids.size - parent_index - 1
        target_group_ancestor_ids.pop(count_to_remove)
      end

      def transform_data(memberships, group)
        return [] unless memberships

        memberships.map do |member|
          ::Namespaces::Export::Member.new(member, group, target_group_ancestor_ids)
        end
      end
    end
  end
end
