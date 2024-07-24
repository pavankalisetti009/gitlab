# frozen_string_literal: true

module EE
  module GroupLink
    module GroupGroupLinkEntity
      extend ActiveSupport::Concern

      prepended do
        expose :access_level, override: true do
          expose :human_access, as: :string_value
          expose :group_access, as: :integer_value
          expose :member_role_id, if: ->(group_link) { can_assign_custom_roles_to_group_links?(group_link) }
        end

        expose :custom_roles do |group_link|
          custom_roles(group_link)
        end

        private

        def can_assign_custom_roles_to_group_links?(group_link)
          group_link.shared_group.custom_roles_enabled? &&
            ::Feature.enabled?(:assign_custom_roles_to_group_links, current_user)
        end

        def custom_roles(group_link)
          return [] unless can_assign_custom_roles_to_group_links?(group_link)

          member_roles = ::MemberRoles::RolesFinder.new(current_user, { parent: group_link.shared_group }).execute

          member_roles.map do |member_role|
            {
              base_access_level: member_role.base_access_level,
              member_role_id: member_role.id,
              name: member_role.name,
              description: member_role.description
            }
          end
        end
      end
    end
  end
end
