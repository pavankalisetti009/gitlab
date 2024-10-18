# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInProjectsPreloader
    include Gitlab::Utils::StrongMemoize

    def initialize(projects:, user:)
      @projects = if projects.is_a?(Array)
                    Project.select(:id, :namespace_id).where(id: projects)
                  else
                    # Push projects base query in to a sub-select to avoid
                    # table name clashes. Performs better than aliasing.
                    Project.select(:id, :namespace_id).where(id: projects.reselect(:id))
                  end

      @user = user
    end

    def execute
      ::Preloaders::ProjectRootAncestorPreloader.new(projects, :namespace).execute

      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: projects.map(&:id)
      ) do
        abilities_for_user_grouped_by_project
      end
    end

    private

    def abilities_for_user_grouped_by_project
      sql_values_array = projects.filter_map do |project|
        next unless custom_roles_enabled_on?(project)

        [project.id, Arel.sql("ARRAY[#{project.namespace.traversal_ids.join(',')}]")]
      end

      return {} if sql_values_array.empty?

      value_list = Arel::Nodes::ValuesList.new(sql_values_array)

      sql = <<~SQL
      SELECT project_ids.project_id, custom_permissions.permissions
        FROM (#{value_list.to_sql}) AS project_ids (project_id, namespace_ids),
        LATERAL (
          #{union_query}
        ) AS custom_permissions
      SQL

      grouped_by_project = ApplicationRecord.connection.execute(sql).to_a.group_by do |h|
        h['project_id']
      end

      grouped_by_project.transform_values do |values|
        project_permissions = values.map do |value|
          Gitlab::Json.parse(value['permissions']).select { |_, v| v }
        end

        project_permissions.inject(:merge).keys.map(&:to_sym) & permissions
      end
    end

    def union_query
      union_queries = []

      member = Member.select('member_roles.permissions')
        .with_user(user)

      project_member = member
        .joins(:member_role)
        .where(source_type: 'Project')
        .where('members.source_id = project_ids.project_id')
        .to_sql

      namespace_member = member
        .joins(:member_role)
        .where(source_type: 'Namespace')
        .where('members.source_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)')
        .to_sql

      if custom_role_for_group_link_enabled?
        group_link_join = member
          .joins('JOIN group_group_links ON members.source_id = group_group_links.shared_with_group_id')
          .where('group_group_links.shared_group_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)')

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

      union_queries.push(project_member, namespace_member, reset_default)

      union_queries.join(" UNION ALL ")
    end

    def custom_roles_enabled_on
      Hash.new do |hash, namespace|
        hash[namespace] = namespace&.custom_roles_enabled?
      end
    end
    strong_memoize_attr :custom_roles_enabled_on

    def custom_roles_enabled_on?(project)
      custom_roles_enabled_on[project&.root_ancestor]
    end

    def resource_key
      "member_roles_in_projects:user:#{user.id}"
    end

    def permissions
      MemberRole
        .all_customizable_project_permissions
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :permissions

    def custom_role_for_group_link_enabled?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        projects.any? { |project| ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, project.root_ancestor) }
      else
        ::Feature.enabled?(:assign_custom_roles_to_group_links_sm, :instance)
      end
    end

    attr_reader :projects, :user
  end
end
