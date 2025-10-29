# frozen_string_literal: true

module EE
  module Projects
    module DuoAgentsPlatformHelper
      def duo_agents_platform_data(project)
        {
          agents_platform_base_route: project_automate_path(project),
          project_id: project.id,
          project_path: project.full_path,
          explore_ai_catalog_path: explore_ai_catalog_path,
          flow_triggers_event_type_options: ai_flow_triggers_event_type_options
        }
      end

      def duo_agents_group_data(group)
        {
          agents_platform_base_route: group_automate_path(group),
          group_id: group.id,
          group_path: group.full_path,
          explore_ai_catalog_path: explore_ai_catalog_path
        }
      end
    end
  end
end
