# frozen_string_literal: true

module EE
  module Projects
    module ProjectMembersHelper
      extend ::Gitlab::Utils::Override

      override :project_members_app_data
      def project_members_app_data(
        project, members:, invited:, access_requests:, include_relations:, search:, pending_members:
      )
        super.merge(
          manage_member_roles_path: manage_member_roles_path(project),
          promotion_request: pending_members.present? ? promotion_pending_members_list_data(pending_members) : [],
          can_approve_access_requests: can_approve_access_requests(project),
          namespace_user_limit: ::Namespaces::FreeUserCap.dashboard_limit
        )
      end

      def can_approve_access_requests(project)
        return true if project.personal?

        !::Namespaces::FreeUserCap::Enforcement.new(project.root_ancestor).reached_limit?
      end

      def project_member_header_subtext(project)
        if project.group &&
            ::Namespaces::FreeUserCap::Enforcement.new(project.root_ancestor).enforce_cap? &&
            can?(current_user, :admin_group_member, project.root_ancestor)
          super + member_header_manage_namespace_members_text(project.root_ancestor)
        else
          super
        end
      end

      override :available_project_roles
      def available_project_roles(project)
        custom_roles = ::MemberRoles::RolesFinder.new(current_user, parent: project).execute
        custom_role_options = custom_roles.map do |member_role|
          { title: member_role.name, value: "custom-#{member_role.id}" }
        end

        super + custom_role_options
      end
    end
  end
end
