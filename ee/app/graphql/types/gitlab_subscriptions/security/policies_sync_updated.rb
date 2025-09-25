# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module Security
      # rubocop:disable Graphql/AuthorizeTypes -- Authorization is handled in subscription
      # rubocop:disable GraphQL/ExtractType -- Not worth combining (merge_requests, merge_requests_total) into a newtype
      class PoliciesSyncUpdated < ::Types::BaseObject
        graphql_name 'PoliciesSyncUpdated'
        # rubocop:disable Layout/LineLength -- Ensures correct Markdown rendering
        description 'Security policy state synchronization update. Returns `null` if the `security_policy_sync_propagation_tracking` feature flag is disabled.'
        # rubocop:enable Layout/LineLength

        field :projects_progress, GraphQL::Types::Float,
          null: true,
          description: 'Percentage of projects synced.'

        field :projects_total, GraphQL::Types::Int,
          null: true,
          description: 'Total number of projects synced.'

        field :failed_projects, [GraphQL::Types::String],
          null: true,
          description: 'IDs of failed projects.'

        field :merge_requests_progress, GraphQL::Types::Float,
          null: true,
          description: 'Percentage of merge requests synced.'

        field :merge_requests_total, GraphQL::Types::Int,
          null: true,
          description: 'Total number of merge requests synced.'

        field :in_progress, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether security policies are currently being synchronized.'
      end
      # rubocop:enable GraphQL/ExtractType
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
