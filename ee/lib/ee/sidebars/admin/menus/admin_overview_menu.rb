# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module AdminOverviewMenu
          extend ::Gitlab::Utils::Override

          override :render?
          def render?
            return super unless ::Feature.enabled?(:custom_ability_read_admin_dashboard, context.current_user)

            return true if context.current_user&.can?(:access_admin_area)

            super
          end
        end
      end
    end
  end
end
