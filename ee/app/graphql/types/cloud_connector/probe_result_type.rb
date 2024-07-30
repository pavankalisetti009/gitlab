# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- this should be callable by anyone

module Types
  module CloudConnector
    class ProbeResultType < Types::BaseObject
      graphql_name 'CloudConnectorProbeResult'

      field :name, GraphQL::Types::String, null: true,
        description: 'Name of the probe.'

      field :success, GraphQL::Types::Boolean, null: true,
        description: 'Indicates if the probe was successful.'

      field :message, GraphQL::Types::String, null: true,
        description: 'Additional message or details about the probe result.'
    end
  end
end
# rubocop: enable Graphql/AuthorizeTypes
