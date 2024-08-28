# frozen_string_literal: true

module EE
  module GroupLink
    module GroupGroupLinkEntity
      extend ActiveSupport::Concern

      prepended do
        include GroupLinksHelper

        expose :access_level, override: true do
          expose :human_access, as: :string_value
          expose :group_access, as: :integer_value
          expose :member_role_id, if: ->(group_link) { custom_role_for_group_link_enabled?(group_link.shared_group) }
        end

        expose :custom_roles do |group_link|
          custom_roles(group_link)
        end

        private

        def custom_roles(group_link)
          return [] unless custom_role_for_group_link_enabled?(group_link.shared_group)

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
