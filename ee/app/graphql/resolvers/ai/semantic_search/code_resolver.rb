# frozen_string_literal: true

module Resolvers
  module Ai
    module SemanticSearch
      class CodeResolver < BaseResolver
        type [::Types::Ai::SemanticSearch::CodeSnippet], null: false
        include Gitlab::Graphql::Authorize::AuthorizeResource

        KNN_COUNT = 10
        SEARCH_RESULTS_LIMIT = 10

        argument :limit,
          ::GraphQL::Types::Int,
          required: false,
          default_value: SEARCH_RESULTS_LIMIT,
          description: 'Max number of search results to return.',
          validates: { numericality: { greater_than: 0 } }

        argument :knn,
          ::GraphQL::Types::Int,
          required: false,
          default_value: KNN_COUNT,
          description: 'KNN count.',
          validates: { numericality: { greater_than: 0 } }

        argument :project,
          ::Types::Ai::SemanticSearch::Project,
          required: true,
          description: 'Project to search, with optional path prefix.'

        argument :search_term,
          ::GraphQL::Types::String,
          required: true,
          description: 'Search term to search for.'

        def resolve(**args)
          if Feature.disabled?(:code_snippet_search_graphqlapi, current_user)
            raise_resource_not_available_error! '`code_snippet_search_graphqlapi` feature flag is disabled.'
          end

          limit = args[:limit]
          knn = args[:knn]
          search_term = args[:search_term]
          projects_info = args[:project]

          codebase_query(search_term).filter(
            project_id: projects_info.project_id,
            path: projects_info.directory_path,
            knn_count: knn,
            limit: limit
          )
        end

        def codebase_query(search_term)
          @codebase_query ||= ::Ai::ActiveContext::Queries::Code.new(
            search_term: search_term, user: current_user)
        end
      end
    end
  end
end
