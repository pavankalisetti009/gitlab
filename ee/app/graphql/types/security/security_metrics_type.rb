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
    end
    # rubocop: enable Graphql/AuthorizeTypes, GraphQL/ExtractType
  end
end
