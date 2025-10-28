# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UserType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUser'
        description 'Describes the user with their usage data'

        authorize :read_user

        field :avatar_url,
          type: GraphQL::Types::String,
          null: true,
          description: "URL of the user's avatar."
        field :events,
          type: [EventType],
          null: true,
          description: 'Billable events from the user.' do
            argument :page, GraphQL::Types::Int,
              required: false,
              default_value: 1,
              description: 'Page number to fetch the events.'
          end
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
          :monthly_commitment_credits_used,
          :overage_credits_used,
          :declarative_policy_subject
        )

        UserEvent = Struct.new(
          :timestamp,
          :event_type,
          :project_id,
          :namespace_id,
          :credits_used,
          :declarative_policy_subject
        )

        def events(page: 1)
          BatchLoader::GraphQL.for(object.id).batch do |user_ids, loader|
            load_users_events(user_ids, page, loader)
          end
        end

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
                monthly_commitment_credits_used: usage[:monthlyCommitmentCreditsUsed],
                overage_credits_used: usage[:overageCreditsUsed],
                declarative_policy_subject: object
              )
            )
          end
        end

        def load_users_events(user_ids, page, loader)
          # We only resolve events if only one user was resolved to avoid overaloading CustomersDot API
          return unless user_ids.length == 1

          result = context[:subscription_usage_client].get_events_for_user_id(user_ids.first, page)

          return unless result[:userEvents]

          user_events = result[:userEvents].map do |event|
            UserEvent.new(
              timestamp: event[:timestamp],
              event_type: event[:eventType],
              project_id: event[:projectId],
              namespace_id: event[:namespaceId],
              credits_used: event[:creditsUsed],
              declarative_policy_subject: object
            )
          end

          loader.call(user_ids.first, user_events)
        end
      end
    end
  end
end
