# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    class SubscriptionUsageType < BaseObject
      graphql_name 'GitlabSubscriptionUsage'
      description 'Describes the usage of consumables under the subscription'

      authorize :read_subscription_usage

      field :pool_usage, SubscriptionUsage::PoolUsageType,
        null: true,
        description: 'Consumption usage for the subscription shared pool.'

      field :users_usage, SubscriptionUsage::UsersUsageType,
        null: true,
        description: 'Consumption usage for users under the subscription.'
    end
  end
end
