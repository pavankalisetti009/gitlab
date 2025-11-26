# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      # rubocop: disable Graphql/AuthorizeTypes -- parent authorization is enough
      class DuoMessageType < Types::BaseObject
        graphql_name 'DuoMessage'
        description 'A message in a Duo Workflow chat log'

        field :content, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Content of the message.'

        field :message_type, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false, description: 'Type of the message.'

        field :status, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Status of the message.'

        field :tool_info, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Tool information for the message.'

        field :timestamp, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Timestamp of the message.'

        field :correlation_id, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Correlation ID of the message.'

        field :role, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Role of the message.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
