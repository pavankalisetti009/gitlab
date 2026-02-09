# frozen_string_literal: true

module Types
  module Security
    # rubocop: disable Graphql/AuthorizeTypes, GraphQL/ExtractType -- not applicable

    class SecurityMetricsType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization is done in resolver layer
      graphql_name 'SecurityMetrics'
      description 'Represents security metrics'

      field :vulnerabilities_per_severity,
        ::Types::Security::VulnerabilitiesPerSeverityType,
        null: true,
        description: 'Count of open vulnerabilities per severity level.
This feature is currently under development and not yet available for general use',
        resolver: ::Resolvers::Security::VulnerabilitiesPerSeverityResolver

      field :vulnerabilities_over_time,
        ::Types::Security::VulnerabilitiesOverTimeType.connection_type,
        null: true,
        description: 'Vulnerability metrics over time with filtering and grouping capabilities.
This feature is currently under development and not yet available for general use',
        resolver: ::Resolvers::Security::VulnerabilitiesOverTimeResolver

      field :risk_score,
        ::Types::Security::RiskScoreType,
        null: true,
        experiment: { milestone: '18.4' },
        description: 'Total risk score information.
This feature is currently under development and not yet available for general use',
        resolver: ::Resolvers::Security::RiskScoreResolver

      field :vulnerabilities_by_age,
        [::Types::Security::VulnerabilitiesByAgeType],
        null: true,
        description: 'Vulnerability age statistics based on predefined age bands.
See [`VulnerabilitiesByAge`](#vulnerabilitiesbyage) for details.
This feature is currently under development and not yet available for general use',
        experiment: { milestone: '18.9' },
        resolver: ::Resolvers::Security::VulnerabilitiesByAgeResolver
    end
    # rubocop: enable Graphql/AuthorizeTypes, GraphQL/ExtractType
  end
end
