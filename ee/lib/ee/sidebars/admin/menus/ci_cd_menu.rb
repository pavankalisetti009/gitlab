# frozen_string_literal: true

module EE
  module Sidebars # rubocop:disable Gitlab/BoundedContexts -- overridden class is not inside a bounded context namespace
    module Admin
      module Menus
        module CiCdMenu
          extend ::Gitlab::Utils::Override

          override :render?
          def render?
            return super if ::Feature.disabled?(:custom_ability_read_admin_cicd, context.current_user)

            return true if context.current_user&.can?(:access_admin_area)

            super
          end
        end
      end
    end
  end
end
