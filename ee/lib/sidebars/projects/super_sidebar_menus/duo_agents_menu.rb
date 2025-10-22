# frozen_string_literal: true

module Sidebars
  module Projects
    module SuperSidebarMenus
      class DuoAgentsMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          return false unless current_user&.can?(:duo_workflow, context.project) &&
            context.project.duo_features_enabled &&
            (show_agents_runs_menu_items? || show_flow_triggers_menu_items? || show_flows_menu_item?)

          add_item(ai_catalog_agents_menu_item) if show_agents_menu_item?
          add_item(duo_flow_triggers_menu_item) if show_flow_triggers_menu_items?
          add_item(ai_catalog_flows_menu_item) if show_flows_menu_item?
          add_item(duo_agents_runs_menu_item) if show_agents_runs_menu_items?

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

        def show_agents_runs_menu_items?
          context.project.duo_remote_flows_enabled && Feature.enabled?(:duo_workflow_in_ci, context.current_user)
        end

        def show_flow_triggers_menu_items?
          context.current_user&.can?(:manage_ai_flow_triggers, context.project)
        end

        def show_agents_menu_item?
          Feature.enabled?(:global_ai_catalog, context.current_user)
        end

        def show_flows_menu_item?
          Feature.enabled?(:global_ai_catalog, context.current_user) &&
            (Feature.enabled?(:ai_catalog_flows,
              context.current_user) || Feature.enabled?(:ai_catalog_third_party_flows, context.current_user))
        end

        def duo_agents_runs_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('DuoAgentsPlatform|Sessions'),
            link: project_automate_agent_sessions_path(context.project),
            active_routes: nil,
            item_id: :agents_runs
          )
        end

        def duo_flow_triggers_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('DuoAgentsPlatform|Flow triggers'),
            link: project_automate_flow_triggers_path(context.project),
            active_routes: nil,
            item_id: :ai_flow_triggers
          )
        end

        def ai_catalog_agents_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|Agents'),
            link: project_automate_agents_path(context.project),
            active_routes: nil,
            item_id: :ai_catalog_agents
          )
        end

        def ai_catalog_flows_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('AICatalog|Flows'),
            link: project_automate_flows_path(context.project),
            active_routes: nil,
            item_id: :ai_flows
          )
        end
      end
    end
  end
end
