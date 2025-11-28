# frozen_string_literal: true

module Mcp
  module Tools
    class SearchCodebaseService < CustomService
      extend ::Gitlab::Utils::Override

      ACTIVE_CONTEXT_QUERY = ::Ai::ActiveContext::Queries
      REQUIRED_ABILITY = :read_code

      # Register version 0.1.0
      register_version '0.1.0', {
        description: <<~DESC.strip,
          Code search using natural language.

          Returns ranked code snippets with file paths and matching content for natural-language queries.

          Primary use cases:
          - When you do not know the exact symbol or file path
          - To see how a behavior or feature is implemented across the codebase
          - To discover related implementations (clients, jobs, feature flags, background workers)

          How to use:
          - Provide a concise, specific query (1–2 sentences) with concrete keywords like endpoint, class, or framework names
          - Add directory_path to narrow scope, e.g., "app/services/" or "ee/app/workers/"
          - Prefer precise intent over broad terms (e.g., "rate limiting middleware for REST API" instead of "rate limit")

          Example queries:
          - semantic_query: "JWT verification middleware" with directory_path: "app/"
          - semantic_query: "CI pipeline triggers downstream jobs" with directory_path: "lib/"
          - semantic_query: "feature flag to disable email notifications" (no directory_path)

          Output:
          - Ranked snippets with file paths and the matched content for each hit
        DESC
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

        # Filter out excluded files based on Duo context exclusion settings
        filtered_results = filter_excluded_results(result.to_a, project)

        lines = filtered_results.map.with_index(1) do |hit, idx|
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
        error_message = result.error_message(target_class: "Project", target_id: project_id)

        ::Mcp::Tools::Response.error(
          "Tool execution failed: Unable to perform semantic search, #{error_message}.",
          error_message
        )
      end

      def codebase_query(semantic_query)
        @codebase_query ||= ACTIVE_CONTEXT_QUERY::Code.new(search_term: semantic_query, user: current_user)
      end

      def filter_excluded_results(results, project)
        return results if results.empty?

        file_paths = results.filter_map { |hit| hit['path'] }.uniq
        return results if file_paths.empty?

        exclusion_result = ::Ai::FileExclusionService.new(project).execute(file_paths)
        return results unless exclusion_result.success?

        excluded_paths = exclusion_result.payload.filter_map { |f| f[:path] if f[:excluded] }.to_set

        results.reject { |hit| excluded_paths.include?(hit['path']) }
      end
    end
  end
end
