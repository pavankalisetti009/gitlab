# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    class SubscriptionUsageType < BaseObject
      graphql_name 'GitlabSubscriptionUsage'
      description 'Describes the usage of consumables under the subscription'

      authorize :read_subscription_usage

      field :last_event_transaction_at, GraphQL::Types::ISO8601DateTime,
        null: true,
        description: 'Date and time when the last usage event resulted in a wallet transaction.'

      field :start_date, GraphQL::Types::ISO8601Date,
        null: true,
        description: 'Start date of the period covered by the usage data.'

      field :end_date, GraphQL::Types::ISO8601Date,
        null: true,
        description: 'End date of the period covered by the usage data.'

      field :purchase_credits_path, GraphQL::Types::String,
        null: true,
        description: 'URL to purchase GitLab Credits.'

      field :one_time_credits, SubscriptionUsage::OneTimeCreditsType,
        null: true,
        description: 'One time credits usage for the subscription.'

      field :monthly_commitment, SubscriptionUsage::MonthlyCommitmentType,
        null: true,
        description: 'Consumption usage for the subscription monthly commitment.'

      field :overage, SubscriptionUsage::OverageType,
        null: true,
        description: 'Overage statistics.'

      field :users_usage, SubscriptionUsage::UsersUsageType,
        null: true,
        description: 'Consumption usage for users under the subscription.'
    end
  end
end
