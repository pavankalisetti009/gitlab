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

      permission_select = permissions.map { |p| "bool_or(custom_permissions.#{p}) AS #{p}" }.join(', ')

      sql = <<~SQL
      SELECT namespace_ids.namespace_id, #{permission_select}
        FROM (#{value_list.to_sql}) AS namespace_ids (namespace_id, namespace_ids),
        LATERAL (
          #{union_query}
        ) AS custom_permissions
        GROUP BY namespace_ids.namespace_id;
      SQL

      grouped_by_group = ApplicationRecord.connection.execute(sql).to_a.group_by do |h|
        h['namespace_id']
      end

      grouped_by_group.transform_values do |value|
        permissions.filter_map do |permission|
          permission if value.find { |custom_role| custom_role[permission.to_s] == true }
        end
      end
    end

    def union_query
      permission_condition = permissions.map do |permission|
        "member_roles.permissions @> ('{\"#{permission}\":true}')::jsonb"
      end.join(' OR ')

      permission_columns = permissions.map { |p| "(member_roles.permissions -> '#{p}')::BOOLEAN as #{p}" }.join(', ')

      permissions_as_false = permissions.map { |p| "false AS #{p}" }.join(', ')

      group_member = Member.select(permission_columns)
        .left_outer_joins(:member_role)
        .where("members.source_type = 'Namespace' AND members.source_id IN (SELECT UNNEST(namespace_ids) as ids)")
        .with_user(user)
        .where(permission_condition)
        .to_sql

      if Feature.enabled?(:assign_custom_roles_to_group_links, user)
        group_link_member = GroupGroupLink.select(permission_columns)
          .joins(:member_role)
          .where('group_group_links.shared_group_id IN (SELECT UNNEST(namespace_ids) as ids)')
          .where(shared_with_group_id: user.member_namespaces.select(:id))
          .where(permission_condition)
          .to_sql
      end

      reset_default = "SELECT #{permissions_as_false}"

      union_queries = [group_member, group_link_member, reset_default]

      union_queries.compact.join(" UNION ALL ")
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

    attr_reader :groups, :user
  end
end
