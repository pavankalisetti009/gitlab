# frozen_string_literal: true

# rubocop:disable Search/NamespacedClass -- this tool will use Mcp as the namespace
module Mcp
  module Tools
    class SearchCodebaseService < CustomService
      extend ::Gitlab::Utils::Override

      override :description
      def description
        'Search for relevant code snippets in a project'
      end

      override :input_schema
      def input_schema
        {
          type: 'object',
          properties: {
            search_term: {
              type: 'string',
              minLength: 1,
              maxLength: 1000,
              description: 'Natural language query for semantic code search.'
            },
            project_id: {
              type: 'integer',
              description: 'Numeric project ID to search in.'
            },
            directory_path: {
              type: 'string',
              minLength: 1,
              maxLength: 100,
              description: 'Optional directory path to scope the search (e.g., "app/services/").'
            },
            knn: {
              type: 'integer',
              default: 64,
              minimum: 1,
              maximum: 100,
              description: 'Number of nearest neighbors used internally.'
            },
            limit: {
              type: 'integer',
              default: 20,
              minimum: 1,
              maximum: 100,
              description: 'Maximum number of results to return.'
            }
          },
          required: %w[search_term project_id],
          additionalProperties: false
        }
      end

      protected

      override :perform
      def perform(arguments = {}, query = {}) # rubocop:disable Lint/UnusedMethodArgument -- `query` is required by the contract
        limit = arguments[:limit] || 20
        knn = arguments[:knn] || 64
        search_term = arguments[:search_term]
        project_id = arguments[:project_id]
        directory_path = arguments[:directory_path]

        result = codebase_query(search_term).filter(
          project_id: project_id,
          path: directory_path,
          knn_count: knn,
          limit: limit
        )

        lines = result.map.with_index(1) do |hit, idx|
          snippet = hit['content']
          "#{idx}. #{hit['path']}\n   #{snippet}"
        end

        formatted_content = [{ type: 'text', text: lines.join("\n") }]

        ::Mcp::Tools::Response.success(formatted_content, result)
      end

      def codebase_query(search_term)
        @codebase_query ||= ::Ai::ActiveContext::Queries::Code.new(search_term: search_term, user: current_user)
      end
    end
  end
end
# rubocop:enable Search/NamespacedClass
