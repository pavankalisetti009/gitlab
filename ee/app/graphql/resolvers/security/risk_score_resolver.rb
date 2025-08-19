# frozen_string_literal: true

module Resolvers
  module Security
    class RiskScoreResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::RiskScoreType, null: true

      authorize :read_security_resource

      def resolve
        authorize!(object) unless resolve_vulnerabilities_for_instance_security_dashboard?

        return if !vulnerable || Feature.disabled?(:new_security_dashboard_total_risk_score, vulnerable)

        # Return dummy data for development and testing
        # This will be replaced with real implementation later
        # https://gitlab.com/gitlab-org/gitlab/-/issues/561341#implementation-plan
        dummy_risk_score_data
      end

      private

      def dummy_risk_score_data
        projects_data = context[:project_id] ? filtered_projects_data(context[:project_id]) : all_projects_data

        {
          score: 5.2,
          rating: 'low',
          factors: {
            vulnerabilities_average_score: {
              factor: 1.0
            }
          },
          by_project: projects_data
        }
      end

      def filtered_projects_data(project_ids)
        # Mock data for specific projects
        project_ids.map do |project_id|
          {
            project: { id: project_id, name: "Project #{project_id}" },
            score: 5.2,
            rating: 'low'
          }
        end
      end

      def all_projects_data
        project_id = context[:project_id].is_a?(Array) ? context[:project_id].first : context[:project_id]

        # Mock data for all projects
        [
          {
            project: { id: project_id, name: 'test-project' },
            score: 5.2,
            rating: 'low'
          }
        ]
      end
    end
  end
end
