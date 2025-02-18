# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module AdminOverviewMenu
          extend ::Gitlab::Utils::Override
          override :configure_menu_items
          def configure_menu_items
            return false unless current_user
            return super if administrator?

            add_item(dashboard_menu_item)
            add_item(users_menu_item)
            add_item(gitaly_servers_menu_item)
          end

          private

          override :render_with_abilities
          def render_with_abilities
            super + %i[read_admin_dashboard read_admin_users]
          end

          override :dashboard_menu_item
          def dashboard_menu_item
            set_menu_item_render(super, :read_admin_dashboard)
          end

          override :users_menu_item
          def users_menu_item
            set_menu_item_render(super, :read_admin_users)
          end

          override :gitaly_servers_menu_item
          def gitaly_servers_menu_item
            set_menu_item_render(super, :read_admin_gitaly_servers)
          end

          def administrator?
            can?(current_user, :admin_all_resources)
          end

          def set_menu_item_render(menu_item, render_with_ability)
            menu_item.render = current_user.can?(render_with_ability) unless administrator?
            menu_item
          end
        end
      end
    end
  end
end
