# frozen_string_literal: true

module Types
  module Ai
    class DescriptionComposerInputType < BaseMethodInputType
      graphql_name 'AiDescriptionComposerInput'

      argument :description, GraphQL::Types::String,
        required: true,
        description: 'Current description.'

      argument :user_prompt, GraphQL::Types::String,
        required: true,
        description: 'Prompt from user.'
    end
  end
end
