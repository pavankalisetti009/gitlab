# frozen_string_literal: true

module EE
  module Projects
    module DuoAgentsPlatformHelper
      def duo_agents_platform_data(project)
        root_group_id = project.personal? ? nil : project.root_namespace.id

        {
          agents_platform_base_route: project_automate_path(project),
          root_group_id: root_group_id,
          project_id: project.id,
          project_path: project.full_path,
          explore_ai_catalog_path: explore_ai_catalog_path,
          ai_impact_dashboard_enabled: ai_impact_dashboard_enabled?.to_s,

          ai_impact_dashboard_path: if ai_impact_dashboard_enabled?
                                      project_analytics_dashboards_path(project,
                                        vueroute: 'duo_and_sdlc_trends')
                                    end
        }
      end

      def duo_agents_group_data(group)
        {
          agents_platform_base_route: group_automate_path(group),
          group_id: group.id,
          group_path: group.full_path,
          explore_ai_catalog_path: explore_ai_catalog_path,
          ai_impact_dashboard_enabled: ai_impact_dashboard_enabled?.to_s,

          ai_impact_dashboard_path: if ai_impact_dashboard_enabled?
                                      group_analytics_dashboards_path(group,
                                        vueroute: 'duo_and_sdlc_trends')
                                    end
        }
      end

      private

      def ai_impact_dashboard_enabled?
        ProductAnalyticsHelpers.ai_impact_dashboard_globally_available?
      end
    end
  end
end
