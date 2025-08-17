# frozen_string_literal: true

module Sidebars
  module Projects
    module SuperSidebarMenus
      class DuoAgentsMenu < ::Sidebars::Menu
        override :configure_menu_items
        def configure_menu_items
          return false unless show_agents_runs_menu_items? || show_flow_triggers_menu_items?

          add_item(duo_agents_runs_menu_item) if show_agents_runs_menu_items?
          add_item(duo_flow_triggers_menu_item) if show_flow_triggers_menu_items?

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

        private

        def show_agents_runs_menu_items?
          context.project.duo_remote_flows_enabled && Feature.enabled?(:duo_workflow_in_ci, context.current_user)
        end

        def show_flow_triggers_menu_items?
          context.current_user&.can?(:manage_ai_flow_triggers, context.project)
        end

        def duo_agents_runs_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Agent sessions'),
            link: project_automate_agent_sessions_path(context.project),
            active_routes: { controller: :duo_agents_platform },
            item_id: :agents_runs
          )
        end

        def duo_flow_triggers_menu_item
          ::Sidebars::MenuItem.new(
            title: s_('Flow triggers'),
            link: project_automate_flow_triggers_path(context.project),
            active_routes: { controller: :duo_agents_platform },
            item_id: :ai_flow_triggers
          )
        end
      end
    end
  end
end
