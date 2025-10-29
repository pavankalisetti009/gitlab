# frozen_string_literal: true

module Sidebars # rubocop:disable Gitlab/BoundedContexts -- Existing module
  module Groups
    module SuperSidebarMenus
      class DuoAgentsMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          return false unless Ability.allowed?(current_user, :duo_workflow, context.group)
          return false unless show_flows_menu_item?

          add_item(ai_catalog_flows_menu_item)

          true
        end

        override :title
        def title
          s_('DuoAgentsPlatform|Automate')
        end

        override :sprite_icon
        def sprite_icon
          'tanuki-ai'
        end

        override :active_routes
        def active_routes
          { controller: :duo_agents_platform }
        end

        private

        def show_flows_menu_item?
          Feature.enabled?(:global_ai_catalog, context.current_user) &&
            Feature.enabled?(:ai_catalog_flows, context.current_user)
        end

        def ai_catalog_flows_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|Flows'),
            link: group_automate_flows_path(context.group),
            active_routes: nil,
            item_id: :ai_flows
          )
        end
      end
    end
  end
end
