# frozen_string_literal: true

# rubocop:disable Search/NamespacedClass -- this tool will use Mcp as the namespace
module Mcp
  module Tools
    class SearchCodebaseService < CustomService
      extend ::Gitlab::Utils::Override

      ACTIVE_CONTEXT_QUERY = ::Ai::ActiveContext::Queries
      REQUIRED_ABILITY = :read_code

      # Register version 0.1.0
      register_version '0.1.0', {
        description: "Performs semantic code search across project files using vector similarity.\n\n" \
          "Returns ranked code snippets with file paths and content matches based on natural language queries.\n\n" \
          "Use this tool for questions about a project's codebase.\n" \
          "For example: \"how something works\" or \"code that does X\", or finding specific implementations.\n\n" \
          "This tool supports directory scoping and configurable result limits for targeted code discovery and " \
          "analysis.",
        input_schema: {
          type: 'object',
          properties: {
            semantic_query: {
              type: 'string',
              minLength: 1,
              maxLength: 1000,
              description: "A brief natural language query about the code you want to find in the project " \
                "(e.g.: 'authentication middleware', 'database connection logic', or 'API error handling')."
            },
            project_id: {
              type: 'string',
              description: 'Either a project id or project path.'
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
              description: "Number of nearest neighbors used internally. " \
                "This controls search precision vs. speed - higher values find more diverse results but take longer."
            },
            limit: {
              type: 'integer',
              default: 20,
              minimum: 1,
              maximum: 100,
              description: 'Maximum number of results to return.'
            }
          },
          required: %w[semantic_query project_id],
          additionalProperties: false
        }
      }

      def available?
        return false unless ACTIVE_CONTEXT_QUERY::Code.available?

        return false unless current_user

        Feature.enabled?(:code_snippet_search_graphqlapi, current_user)
      end

      override :ability
      def auth_ability
        REQUIRED_ABILITY
      end

      override :auth_target
      def auth_target(params)
        project_id = params.dig(:arguments, :project_id)

        raise ArgumentError, "#{name}: project not found, the params received: #{params.inspect}" if project_id.nil?

        find_project(project_id)
      end

      protected

      # Version 0.1.0 implementation
      def perform_0_1_0(arguments = {})
        limit = arguments[:limit] || 20
        knn = arguments[:knn] || 64
        semantic_query = arguments[:semantic_query]
        project_id = arguments[:project_id]
        directory_path = arguments[:directory_path]

        project = find_project(project_id)

        exclude_fields = %w[id source type embeddings_v1 reindexing]

        result = codebase_query(semantic_query).filter(
          project_id: project.id,
          path: directory_path,
          knn_count: knn,
          limit: limit,
          exclude_fields: exclude_fields,
          extract_source_segments: true
        )

        return failure_response(result, project_id) unless result.success?

        lines = result.map.with_index(1) do |hit, idx|
          snippet = hit['content']
          "#{idx}. #{hit['path']}\n   #{snippet}"
        end

        formatted_content = [{ type: 'text', text: lines.join("\n") }]

        ::Mcp::Tools::Response.success(formatted_content, result.to_a)
      end

      # Fallback to 0.1.0 behavior for any unimplemented versions
      override :perform_default
      def perform_default(arguments = {})
        perform_0_1_0(arguments)
      end

      private

      def failure_response(result, project_id)
        error_message = case result.error_code
                        when ACTIVE_CONTEXT_QUERY::Result::ERROR_NO_EMBEDDINGS
                          "Unable to perform semantic search, project '#{project_id}' has no Code Embeddings"
                        else
                          "Unknown error"
                        end

        ::Mcp::Tools::Response.error(
          "Tool execution failed: #{error_message}",
          error_message
        )
      end

      def codebase_query(semantic_query)
        @codebase_query ||= ACTIVE_CONTEXT_QUERY::Code.new(search_term: semantic_query, user: current_user)
      end
    end
  end
end
# rubocop:enable Search/NamespacedClass
