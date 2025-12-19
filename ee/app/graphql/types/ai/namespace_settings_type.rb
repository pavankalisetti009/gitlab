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

      field :prompt_injection_protection_level,
        ::Types::Ai::PromptInjectionProtectionLevelEnum,
        null: false,
        description: 'Level of prompt injection protection for the namespace.'
    end
  end
end
