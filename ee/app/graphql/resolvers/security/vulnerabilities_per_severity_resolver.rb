# frozen_string_literal: true

module Resolvers
  module Security
    class VulnerabilitiesPerSeverityResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_DATE_RANGE_DAYS = 1.year.in_days.floor.freeze

      type Types::Security::VulnerabilitiesPerSeverityType, null: true

      authorize :read_security_resource

      argument :start_date, GraphQL::Types::ISO8601Date,
        required: false,
        experiment: { milestone: '18.3' },
        description: 'Start date for the vulnerability metrics time range. Defaults to 365 days ago if not provided.'

      argument :end_date, GraphQL::Types::ISO8601Date,
        required: false,
        experiment: { milestone: '18.3' },
        description: 'End date for the vulnerability metrics time range. Defaults to current date if not provided.'

      def resolve(start_date: nil, end_date: nil)
        authorize!(object) unless resolve_vulnerabilities_for_instance_security_dashboard?

        start_date ||= 365.days.ago.to_date
        end_date ||= Date.current

        validate_date_range!(start_date, end_date)

        return {} if !vulnerable || Feature.disabled?(:new_security_dashboard_vulnerabilities_per_severity, vulnerable)

        params = build_base_params(start_date, end_date)

        fetch_results(params)
      end

      private

      def validate_date_range!(start_date, end_date)
        raise Gitlab::Graphql::Errors::ArgumentError, "start date cannot be after end date" if start_date > end_date

        return unless (end_date - start_date) > MAX_DATE_RANGE_DAYS

        raise Gitlab::Graphql::Errors::ArgumentError, "maximum date range is #{MAX_DATE_RANGE_DAYS} days"
      end

      def build_base_params(start_date, end_date)
        project_ids = context[:project_id]
        report_type = context[:report_type]

        {
          created_after: start_date,
          created_before: end_date,
          project_id: project_ids,
          report_type: report_type
        }.compact
      end

      def fetch_results(params)
        finder = ::Security::VulnerabilityElasticCountBySeverityFinder.new(vulnerable, params)
        counts = finder.execute

        ::Enums::Vulnerability.severity_levels.each_key.index_with do |severity|
          counts[severity.to_s] || 0
        end
      end
    end
  end
end
