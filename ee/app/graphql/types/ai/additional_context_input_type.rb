# frozen_string_literal: true

module Types
  module Ai
    class AdditionalContextInputType < BaseInputObject
      graphql_name 'AiAdditionalContextInput'

      MAX_BODY_SIZE = ::API::CodeSuggestions::MAX_BODY_SIZE
      MAX_CONTEXT_NAME_SIZE = ::API::CodeSuggestions::MAX_CONTEXT_NAME_SIZE

      argument :id, GraphQL::Types::String,
        required: true,
        description: 'ID of the additional context.',
        validates: { length: { maximum: MAX_CONTEXT_NAME_SIZE } }

      argument :category, Types::Ai::AdditionalContextCategoryEnum,
        required: true,
        description: 'Category of the additional context.'

      argument :content, GraphQL::Types::String,
        required: true,
        description: 'Content of the additional context.',
        validates: { length: { maximum: MAX_BODY_SIZE } }

      argument :metadata, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- As per discussion on https://gitlab.com/gitlab-org/gitlab/-/issues/481548, we want metadata to be a flexible unstructured field
        required: false,
        description: 'Metadata of the additional context.'
    end
  end
end
