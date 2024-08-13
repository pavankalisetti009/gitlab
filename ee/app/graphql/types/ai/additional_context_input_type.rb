# frozen_string_literal: true

module Types
  module Ai
    class AdditionalContextInputType < BaseInputObject
      graphql_name 'AiAdditionalContextInput'

      MAX_BODY_SIZE = ::API::CodeSuggestions::MAX_BODY_SIZE
      MAX_CONTEXT_NAME_SIZE = ::API::CodeSuggestions::MAX_CONTEXT_NAME_SIZE

      argument :type, Types::Ai::AdditionalContextTypeEnum,
        required: true,
        description: 'Type of the additional context.'

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name of the additional context.',
        validates: { length: { maximum: MAX_CONTEXT_NAME_SIZE } }

      argument :content, GraphQL::Types::String,
        required: true,
        description: 'Content of the additional context.',
        validates: { length: { maximum: MAX_BODY_SIZE } }
    end
  end
end
