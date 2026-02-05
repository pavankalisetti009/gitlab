# frozen_string_literal: true

module Mcp
  module Tools
    class SemanticCodeSearchService < CustomService
      include ::Gitlab::Utils::StrongMemoize
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
        },
        annotations: {
          readOnlyHint: true
        }
      }

      SCORE_DESCRIPTION = <<~DESC.strip
        - Each result includes a score field (0.0 to 1.0) indicating semantic similarity to your query
          - Higher scores mean the code is more relevant; results are sorted by score descending
          - Scores above 0.8 typically indicate strong matches; below 0.5 may be tangentially related
      DESC

      CONFIDENCE_DESCRIPTION = <<~DESC.strip
        - Results include an overall confidence level (high/medium/low/unknown) based on score distribution:
          - HIGH: Strong match with clear winner - answer directly with confidence
          - MEDIUM: Multiple reasonable matches - present results but consider alternatives
          - LOW: Ambiguous or weak matches - consider asking user for clarification
          - UNKNOWN: Confidence cannot be determined (e.g., storage backend doesn't provide scores)
      DESC

      GROUPING_DESCRIPTION = <<~DESC.strip
        - Results are grouped by file path with sequential line ranges merged
        - Each file group shows all relevant code regions from that file
        - Group score is the maximum score among all snippets in that file
      DESC

      HIGH_SCORE_THRESHOLD = 0.75
      MEDIUM_SCORE_THRESHOLD = 0.5
      STEEP_DROPOFF_THRESHOLD = 0.15

      def available?
        current_user.present? && ACTIVE_CONTEXT_QUERY::Code.available?
      end

      override :description
      def description
        base_description = super
        parts = [base_description]

        parts << SCORE_DESCRIPTION if include_score_in_response?
        parts << CONFIDENCE_DESCRIPTION if include_confidence_in_response?
        parts << GROUPING_DESCRIPTION if group_by_file?

        parts.join("\n")
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
        exclude_fields << 'score' unless include_score_in_response?

        result = codebase_query(semantic_query).filter(
          project_or_id: project,
          path: directory_path,
          knn_count: knn,
          limit: limit,
          exclude_fields: exclude_fields,
          extract_source_segments: true,
          build_file_url: true
        )

        return failure_response(result, project_id) unless result.success?

        # Filter out excluded files based on Duo context exclusion settings
        filtered_results = filter_excluded_results(result.to_a, project)

        formatted_text_output, structured_data = post_process_results(filtered_results)

        ::Mcp::Tools::Response.success(formatted_text_output, structured_data)
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

      def include_score_in_response?
        ::Feature.enabled?(:post_process_semantic_code_search_add_score, current_user)
      end
      strong_memoize_attr :include_score_in_response?

      def include_confidence_in_response?
        ::Feature.enabled?(:post_process_semantic_code_search_overall_confidence, current_user)
      end
      strong_memoize_attr :include_confidence_in_response?

      def group_by_file?
        ::Feature.enabled?(:post_process_semantic_code_search_group_by_file, current_user)
      end
      strong_memoize_attr :group_by_file?

      def post_process_results(filtered_results)
        confidence = include_confidence_in_response? ? compute_confidence_level(extract_scores(filtered_results)) : nil
        results = group_by_file? ? group_results_by_file(filtered_results) : filtered_results

        [
          build_text_content(results, is_grouped: group_by_file?, confidence: confidence),
          build_structured_data(results, confidence: confidence)
        ]
      end

      def build_text_content(results, is_grouped:, confidence:)
        text_output = is_grouped ? format_grouped_text(results) : format_flat_text(results)
        text_output = "Confidence: #{confidence.to_s.upcase}\n\n#{text_output}" if confidence

        [{ type: 'text', text: text_output }]
      end

      def build_structured_data(results, confidence:)
        metadata = { count: results.length, has_more: false }
        metadata[:confidence] = confidence if confidence

        { items: results, metadata: metadata }
      end

      def extract_scores(results)
        results.filter_map { |hit| hit['score'] }
      end

      def format_flat_text(results)
        lines = results.map.with_index(1) do |hit, idx|
          snippet = hit['content']
          score_str = hit['score'] ? format(' (score: %.4f)', hit['score']) : ''

          "#{idx}. #{hit['path']}#{score_str}\n#{snippet}"
        end

        lines.join("\n")
      end

      def format_grouped_text(grouped_results)
        lines = grouped_results.map.with_index(1) do |group, idx|
          score_str = ''
          score_str = format(' (score: %.4f)', group[:score]) if include_score_in_response? && group[:score]

          ranges_text = group[:snippet_ranges].map do |range|
            "[Lines #{range[:start_line]}-#{range[:end_line]}]\n#{range[:content]}"
          end.join("\n")

          "#{idx}. #{group[:path]}#{score_str}\n#{ranges_text}"
        end

        lines.join("\n\n")
      end

      def group_results_by_file(filtered_results)
        return [] if filtered_results.empty?

        groups_by_path = filtered_results.group_by { |hit| hit['path'] }

        groups_after_merging = groups_by_path.map do |path, hits|
          sorted_hits = hits.sort_by { |hit| hit['start_line'] || 0 }
          merged_ranges = merge_sequential_ranges(sorted_hits)

          first_hit = sorted_hits.first
          group = {
            path: path,
            project_id: first_hit['project_id'],
            language: first_hit['language'],
            blob_id: first_hit['blob_id'],
            snippet_ranges: merged_ranges
          }
          group[:score] = merged_ranges.filter_map { |r| r[:score] }.max if include_score_in_response?
          group
        end

        groups_after_merging.sort_by { |group| -(group[:score] || 0) }
      end

      def merge_sequential_ranges(sorted_hits)
        return [] if sorted_hits.empty?

        ranges = []
        current_range = nil

        sorted_hits.each do |hit|
          start_line = hit['start_line'] || 0
          end_line = compute_end_line(hit)
          content = hit['content']

          if current_range.nil?
            current_range = build_range(start_line, end_line, content, hit)
          elsif start_line == current_range[:end_line] + 1
            current_range[:end_line] = end_line
            current_range[:content] = "#{current_range[:content]}\n#{content}"
            current_range[:score] = [current_range[:score], hit['score']].compact.max if include_score_in_response?
          else
            ranges << current_range
            current_range = build_range(start_line, end_line, content, hit)
          end
        end

        ranges << current_range
        ranges
      end

      def build_range(start_line, end_line, content, hit)
        range = { start_line: start_line, end_line: end_line, content: content }
        range[:score] = hit['score'] if include_score_in_response?
        range
      end

      def compute_end_line(hit)
        start_line = hit['start_line'] || 0
        start_line + (hit['content'] || '').count("\n")
      end

      def compute_confidence_level(scores)
        return :unknown if scores.empty?

        top_score = scores.first
        return :low if top_score < MEDIUM_SCORE_THRESHOLD

        # Check for steep drop-off (clear winner)
        if scores.size > 1 && top_score >= HIGH_SCORE_THRESHOLD && top_score - scores[1] >= STEEP_DROPOFF_THRESHOLD
          return :high
        end

        # Single result with high score
        return :high if scores.size <= 1 && top_score >= HIGH_SCORE_THRESHOLD

        # Medium: reasonable top score but no clear winner
        :medium
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
