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
            project: Project.new(id: project_id, name: "Project #{project_id}", path: "Project #{project_id}"),
            score: 5.2,
            rating: 'low'
          }
        end
      end

      def all_projects_data
        project_types = %w[web mobile api data frontend backend microservice legacy admin dashboard]
        project_suffixes = %w[service app system platform tool pipeline gateway proxy manager client]

        # Generate mock data for multiple projects with randomized score and project name
        (1..rand(1..100)).map do |i|
          score = rand(1.0..100.0).round(1)
          rating = case score
                   when 0..25.9 then 'low'
                   when 26..50.9 then 'medium'
                   when 51..75.9 then 'high'
                   when 76..100 then 'critical'
                   else 'unknown'
                   end

          project_name = "#{project_types.sample}-#{project_suffixes.sample}"

          {
            project: Project.new(id: i, name: project_name, path: "project-#{i}"),
            score: score,
            rating: rating
          }
        end
      end
    end
  end
end
