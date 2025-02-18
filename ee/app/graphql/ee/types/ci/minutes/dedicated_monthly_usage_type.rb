# frozen_string_literal: true

# rubocop:disable Gitlab/EeOnlyClass -- This is only used in GitLab dedicated that comes under ultimate tier only.
module EE
  module Types
    module Ci
      module Minutes
        class DedicatedMonthlyUsageType < ::Types::BaseObject
          graphql_name 'CiDedicatedHostedRunnerUsage'
          description 'Compute usage data for hosted runners on GitLab Dedicated.'

          authorize :read_dedicated_hosted_runner_usage

          field :billing_month, GraphQL::Types::String, null: false,
            method: :billing_month_formatted,
            description: 'Month of the usage data.'

          field :billing_month_iso8601, GraphQL::Types::ISO8601Date, null: false, # rubocop:disable GraphQL/ExtractType -- we need it separate
            description: 'Timestamp of the billing month in ISO 8601 format.'

          field :compute_minutes, GraphQL::Types::Int, null: false,
            description: 'Total compute minutes used across all namespaces.'

          field :duration_seconds, GraphQL::Types::Int, null: false,
            description: 'Total duration in seconds of runner usage.'

          field :root_namespace, ::Types::NamespaceType, null: true,
            description: 'Namespace associated with the usage data. Null for instance aggregate data.'
        end
      end
    end
  end
end
# rubocop:enable Gitlab/EeOnlyClass
