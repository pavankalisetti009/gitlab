# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UserUsageType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUserUsage'
        description 'Describes the usage of consumables for a user under the subscription'

        authorize :read_user

        field :credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'GitLab Credits used by the user.'
        field :monthly_commitment_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'GitLab Credits from the subscription monthly commitment used by the user.'
        field :overage_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Overage GitLab Credits used by the user.'
        field :total_credits,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total GitLab Credits available for the user.'
      end
    end
  end
end
