# frozen_string_literal: true

module Types
  module Notes
    class QuickActionsStatusType < BaseObject
      graphql_name 'QuickActionsStatus'

      authorize :read_note

      field :messages, [GraphQL::Types::String],
        null: true,
        description: 'Quick action response messages.'

      field :command_names, [GraphQL::Types::String],
        null: true,
        description: 'Quick action command names.'

      field :commands_only, GraphQL::Types::Boolean,
        null: true,
        description: 'Returns true if only quick action commands were in the note.'

      field :error, GraphQL::Types::Boolean,
        null: true,
        description: 'Error in processing quick actions.'
    end
  end
end
