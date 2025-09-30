# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UsersUsageType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUsersUsage'
        description 'Describes the usage of consumables by users under the subscription'

        authorize :read_subscription_usage

        field :users, UsersType.connection_type,
          null: true,
          description: 'List of users with their usage data.'
      end
    end
  end
end
