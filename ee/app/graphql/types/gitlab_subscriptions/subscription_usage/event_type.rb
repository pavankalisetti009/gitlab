# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class EventType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUserEvent'
        description 'Describes a usage event for the subscription.'

        authorize :read_user

        field :timestamp,
          GraphQL::Types::ISO8601DateTime,
          null: true,
          description: 'Date and time of the event.'

        field :event_type,
          GraphQL::Types::String,
          null: true,
          description: 'Event type.'

        field :location,
          EventLocationType,
          null: true,
          description: 'Event location: project or namespace.'

        field :credits_used,
          GraphQL::Types::Float,
          null: true,
          description: 'GitLab Credits consumed on the date.'

        def location
          if object.project_id
            Gitlab::Graphql::Loaders::BatchModelLoader.new(Project, object.project_id).find
          else
            Gitlab::Graphql::Loaders::BatchModelLoader.new(Group, object.namespace_id).find
          end
        end
      end
    end
  end
end
