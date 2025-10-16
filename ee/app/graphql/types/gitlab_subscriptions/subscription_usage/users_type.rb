# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UsersType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUsers'
        description 'Describes the user with their usage data'

        authorize :read_user

        field :avatar_url,
          type: GraphQL::Types::String,
          null: true,
          description: "URL of the user's avatar."
        field :id,
          type: GlobalIDType[::User],
          null: false,
          description: 'Global ID of the user.'
        field :name,
          type: GraphQL::Types::String,
          null: false,
          resolver_method: :redacted_name,
          description: 'Human-readable name of the user.'
        field :usage,
          type: UserUsageType,
          null: true,
          description: 'Usage of consumables for a user under the subscription.'
        field :username,
          type: GraphQL::Types::String,
          null: false,
          description: 'Username of the user. Unique within the instance of GitLab.'

        UserUsage = Struct.new(
          :total_credits,
          :credits_used,
          :pool_credits_used,
          :overage_credits_used,
          :declarative_policy_subject
        )

        def usage
          BatchLoader::GraphQL.for(object.id).batch do |user_ids, loader|
            load_users_usage(user_ids, loader)
          end
        end

        private

        def load_users_usage(user_ids, loader)
          result = context[:subscription_usage_client].get_usage_for_user_ids(user_ids)

          return unless result[:usersUsage]

          result[:usersUsage].each do |usage|
            loader.call(
              usage[:userId],
              UserUsage.new(
                total_credits: usage[:totalCredits],
                credits_used: usage[:creditsUsed],
                pool_credits_used: usage[:poolCreditsUsed],
                overage_credits_used: usage[:overageCreditsUsed],
                declarative_policy_subject: object
              )
            )
          end
        end
      end
    end
  end
end
