# frozen_string_literal: true

module Types
  module Ai
    class NamespaceSettingsType < BaseObject
      graphql_name 'AiNamespaceSettings'

      authorize :read_namespace

      field :duo_workflow_mcp_enabled,
        GraphQL::Types::Boolean,
        null: false,
        description: 'Indicates whether the namespace has MCP enabled.'
    end
  end
end
