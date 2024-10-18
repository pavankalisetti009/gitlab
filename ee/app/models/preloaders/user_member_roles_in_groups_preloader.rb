# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInGroupsPreloader
    include Gitlab::Utils::StrongMemoize

    def initialize(groups:, user:)
      @groups = if groups.is_a?(Array)
                  Group.where(id: groups)
                else
                  # Push groups base query in to a sub-select to avoid
                  # table name clashes. Performs better than aliasing.
                  Group.where(id: groups.reselect(:id))
                end

      @user = user
    end

    def execute
      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: groups.map(&:id)
      ) do
        abilities_for_user_grouped_by_group
      end
    end

    private

    def abilities_for_user_grouped_by_group
      sql_values_array = groups.filter_map do |group|
        next unless group.custom_roles_enabled?

        [group.id, Arel.sql("ARRAY[#{group.traversal_ids.join(',')}]")]
      end

      return {} if sql_values_array.empty?

      value_list = Arel::Nodes::ValuesList.new(sql_values_array)

      sql = <<~SQL
      SELECT namespace_ids.namespace_id, custom_permissions.permissions
        FROM (#{value_list.to_sql}) AS namespace_ids (namespace_id, namespace_ids),
        LATERAL (
          #{union_query}
        ) AS custom_permissions
      SQL

      grouped_by_group = ApplicationRecord.connection.execute(sql).to_a.group_by do |h|
        h['namespace_id']
      end

      grouped_by_group.transform_values do |values|
        group_permissions = values.map do |value|
          Gitlab::Json.parse(value['permissions']).select { |_, v| v }
        end

        group_permissions.inject(&:merge).keys.map(&:to_sym) & permissions
      end
    end

    def union_query
      union_queries = []

      member = Member.select('member_roles.permissions')
        .with_user(user)

      group_member = member
        .joins(:member_role)
        .where(source_type: 'Namespace')
        .where('members.source_id IN (SELECT UNNEST(namespace_ids) as ids)')
        .to_sql

      if custom_role_for_group_link_enabled?
        group_link_join = member
          .joins('JOIN group_group_links ON members.source_id = group_group_links.shared_with_group_id')
          .where('group_group_links.shared_group_id IN (SELECT UNNEST(namespace_ids) as ids)')

        invited_member_role = group_link_join
          .joins('JOIN member_roles ON member_roles.id = group_group_links.member_role_id')
          .where('access_level > group_access')
          .to_sql

        # when both roles are custom roles with the same base access level,
        # choose the source role as the max role
        source_member_role = group_link_join
          .joins('JOIN member_roles ON member_roles.id = members.member_role_id')
          .where('(access_level < group_access) OR ' \
            '(access_level = group_access AND group_group_links.member_role_id IS NOT NULL)')
          .to_sql

        union_queries.push(invited_member_role, source_member_role)
      end

      reset_default = "SELECT '{}'::jsonb AS permissions"

      union_queries.push(group_member, reset_default)

      union_queries.join(" UNION ALL ")
    end

    def resource_key
      "member_roles_in_groups:user:#{user.id}"
    end

    def permissions
      MemberRole
        .all_customizable_group_permissions
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :permissions

    def custom_role_for_group_link_enabled?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        groups.any? { |group| ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, group.root_ancestor) }
      else
        ::Feature.enabled?(:assign_custom_roles_to_group_links_sm, :instance)
      end
    end

    attr_reader :groups, :user
  end
end
