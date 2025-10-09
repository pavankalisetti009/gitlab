# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class PoolUsageType < BaseObject
        graphql_name 'GitlabSubscriptionPoolUsage'
        description 'Describes the usage of consumables for the subscription shared pool'

        authorize :read_subscription_usage

        field :total_credits,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total of GitLab Credits allocated to the subscription.'

        field :credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total of GitLab Credits consumed by the subscription.'

        field :daily_usage,
          [DailyUsageType],
          null: true,
          description: 'Array of daily usage of pool GitLab Credits.'
      end
    end
  end
end
