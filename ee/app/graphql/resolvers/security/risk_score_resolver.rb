# frozen_string_literal: true

module Resolvers
  module Security
    class RiskScoreResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Security::RiskScoreType, null: true

      authorize :read_security_resource

      def resolve
        authorize!(object) unless resolve_vulnerabilities_for_instance_security_dashboard?
        validate_advanced_vuln_management!

        return if !vulnerable || Feature.disabled?(:new_security_dashboard_total_risk_score, vulnerable)

        base_params = build_base_params

        risk_score_data = fetch_risk_score_data(base_params)

        transform_risk_score_data(risk_score_data)
      end

      private

      def build_base_params
        project_ids = context[:project_id]

        {
          project_id: project_ids,
          group_by: vulnerable.is_a?(Group) ? :project : nil
        }.compact
      end

      def fetch_risk_score_data(params)
        finder = ::Search::AdvancedFinders::Security::Vulnerability::RiskScoresFinder.new(vulnerable, params)
        finder.execute
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e)
        nil
      end

      def transform_risk_score_data(risk_score_data)
        return if risk_score_data.nil? || risk_score_data.empty?

        normalized_score = normalize_score(risk_score_data[:total_risk_score])

        result = {
          score: normalized_score,
          rating: rating(normalized_score),
          project_count: risk_score_data[:total_project_count] || 0
        }

        by_project = projects_data(risk_score_data[:risk_score_by_project]) if vulnerable.is_a?(Group)
        result[:by_project] = by_project if by_project

        result
      end

      def projects_data(risk_score_by_project_data)
        return if risk_score_by_project_data.nil? || risk_score_by_project_data.empty?

        project_ids = risk_score_by_project_data.keys

        projects = vulnerable.all_projects.id_in(project_ids)

        projects.map do |project|
          normalized_score = normalize_score(risk_score_by_project_data[project.id])

          {
            project: project,
            score: normalized_score,
            rating: rating(normalized_score)
          }
        end
      end

      def normalize_score(score)
        return if score.nil?

        (score * 100).round(1)
      end

      def rating(score)
        case score
        when 0..25.9 then 'low'
        when 26..50.9 then 'medium'
        when 51..75.9 then 'high'
        when 76..100 then 'critical'
        else 'unknown'
        end
      end
    end
  end
end
