# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes -- No specialized authorization needed to see slash command data
    class SlashCommandType < Types::BaseObject
      graphql_name 'SlashCommand'
      description "Duo Chat slash command"

      field :command, GraphQL::Types::String, null: false,
        description: 'Full slash command including the leading `/`.'
      field :description, GraphQL::Types::String, null: false,
        description: 'Description of what the slash command does.'
      field :name, GraphQL::Types::String, null: false,
        description: 'Name of the slash command.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
