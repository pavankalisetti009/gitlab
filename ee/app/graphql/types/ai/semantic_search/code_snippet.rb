# frozen_string_literal: true

module Types
  module Ai
    module SemanticSearch
      class CodeSnippet < ::Types::BaseObject # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
        graphql_name 'SemanticSearchCode'
        description 'Code snippet returned by semantic search.'

        field :path, String, null: false, description: 'File path to the code snippet.'

        field :content, String, null: false, description: 'Content of the code snippet.'
      end
    end
  end
end
