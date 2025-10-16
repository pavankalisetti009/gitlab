# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UsersUsageType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUsersUsage'
        description 'Describes the usage of consumables by users under the subscription'

        authorize :read_subscription_usage

        # rubocop: disable GraphQL/ExtractType -- no value for now
        field :total_users_using_credits, GraphQL::Types::Int, null: true,
          description: 'Total number of users consuming GitLab Credits.'

        field :total_users_using_pool, GraphQL::Types::Int, null: true,
          description: 'Total number of users consuming pool GitLab Credits.'

        field :total_users_using_overage, GraphQL::Types::Int, null: true,
          description: 'Total number of users consuming overage.'
        # rubocop:enable GraphQL/ExtractType

        field :users, UsersType.connection_type,
          null: true,
          description: 'List of users with their usage data.'
      end
    end
  end
end
