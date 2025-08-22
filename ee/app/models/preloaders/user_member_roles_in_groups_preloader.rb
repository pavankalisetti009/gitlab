# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInGroupsPreloader
    include Gitlab::Utils::StrongMemoize

    attr_reader :groups, :group_relation, :groups_with_traversal_ids, :user

    def initialize(groups:, user:)
      @groups = groups
      @user = user
    end

    def execute
      return {} if groups.blank? || user.blank?

      group_ids = groups.map { |group| group.respond_to?(:id) ? group.id : group }

      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: group_ids,
        default_value: []
      ) do |group_ids|
        abilities_for_user_grouped_by_group(group_ids)
      end
    end

    private

    def abilities_for_user_grouped_by_group(group_ids)
      build_groups_with_traversal_ids(group_ids)

      log_statistics(group_ids)

      get_results(union_query).tap do |existing_query_results|
        track_diff(existing_query_results)
      end
    end

    def build_groups_with_traversal_ids(group_ids)
      @group_relation = Group.id_in(group_ids)

      ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(group_relation).execute

      @groups_with_traversal_ids = group_relation.filter_map do |group|
        next unless group.root_ancestor.should_process_custom_roles?

        [group.id, Arel.sql("ARRAY[#{group.traversal_ids_as_sql}]")]
      end
    end

    def get_results(query)
      return {} if groups_with_traversal_ids.empty?

      value_list = Arel::Nodes::ValuesList.new(groups_with_traversal_ids)

      sql = <<~SQL
      SELECT namespace_ids.namespace_id, custom_permissions.permissions
        FROM (#{value_list.to_sql}) AS namespace_ids (namespace_id, namespace_ids),
        LATERAL (
          #{query}
        ) AS custom_permissions
      SQL

      grouped_by_group = ApplicationRecord.connection.select_all(sql).to_a.group_by do |h|
        h['namespace_id']
      end

      grouped_by_group.transform_values do |values|
        group_permissions = values.map do |value|
          Gitlab::Json.parse(value['permissions']).select { |_, v| v }
        end

        group_permissions.inject(&:merge).keys.map(&:to_sym) & enabled_group_permissions
      end
    end

    def union_query
      union_queries = []

      member = Member.select('member_roles.permissions').with_user(user)

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

      union_queries.push(group_member)

      union_queries.join(" UNION ALL ")
    end

    def user_group_member_roles_query
      query = ::Authz::UserGroupMemberRole.joins(:member_role)
          .where('user_group_member_roles.group_id IN (SELECT UNNEST(namespace_ids) as ids)')
          .where(user: user)

      # Exclude permissions granted through group sharing
      #
      # Remove this condition when assign_custom_roles_to_group_links_saas and
      # assign_custom_roles_to_group_links_sm feature flags are removed
      query = query.where(shared_with_group: nil) unless custom_role_for_group_link_enabled?

      query.select('member_roles.permissions').to_sql
    end

    def resource_key
      "member_roles_in_groups:user:#{user.id}"
    end

    def enabled_group_permissions
      MemberRole.all_customizable_group_permissions
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :enabled_group_permissions

    def custom_role_for_group_link_enabled?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        group_relation.any? do |group|
          ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, group.root_ancestor)
        end
      else
        ::Feature.enabled?(:assign_custom_roles_to_group_links_sm, :instance)
      end
    end

    def log_statistics(group_ids)
      ::Gitlab::AppLogger.info(
        class: self.class.name,
        user_id: user.id,
        groups_count: group_ids.length,
        group_ids: group_ids.first(10)
      )
    end

    def track_diff(existing_query_results)
      return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      return if ::Feature.disabled?(:track_user_group_member_roles_accuracy, Feature.current_request)

      group_ids = groups_with_traversal_ids.map(&:first)

      # Limit diff checks to usage with <= 20 input groups. This prevents log
      # explosion for cases where input groups count is in the hundreds (e.g.
      # global search).
      return if group_ids.length > 20

      group_ids_with_diff = []
      cached_permissions = []
      uncached_permissions = []

      cached_results = get_results(user_group_member_roles_query)

      group_ids.each do |id|
        cached_permissions = extract_permissions(cached_results, id)
        uncached_permissions = extract_permissions(existing_query_results, id)

        next if cached_permissions == uncached_permissions

        group_ids_with_diff << id
      end

      return if group_ids_with_diff.empty?

      log_info = { class: self.class.name, event: 'Inaccurate user_group_member_roles data', user_id: user.id }
      log_info = if group_ids_with_diff.length > 1
                   log_info.merge(group_ids: group_ids_with_diff)
                 else
                   log_info.merge(
                     group_id: group_ids_with_diff.first,
                     permissions: uncached_permissions,
                     user_group_member_roles_permissions: cached_permissions
                   )
                 end

      ::Gitlab::AppLogger.info(**log_info)
    end

    def extract_permissions(result, group_id)
      result.fetch(group_id, []).sort.join(', ')
    end
  end
end
