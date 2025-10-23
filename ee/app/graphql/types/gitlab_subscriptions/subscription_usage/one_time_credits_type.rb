# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class OneTimeCreditsType < BaseObject
        graphql_name 'GitlabSubscriptionOneTimeCredits'
        description 'Describes the usage of one time credits for the subscription'

        authorize :read_subscription_usage

        field :credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'GitLab Credits used from the one time credits allocation.'

        # rubocop: disable GraphQL/ExtractType -- no value for now
        field :total_credits,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total of GitLab Credits allocated as one time credits.'

        field :total_credits_remaining,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total of GitLab Credits remaining from the one time credits allocation.'
        # rubocop:enable GraphQL/ExtractType
      end
    end
  end
end
