# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CodebaseSearch
          class Executor < Tool # rubocop: disable Search/NamespacedClass -- this is a Duo Chat tool
            include ::Gitlab::Llm::Concerns::Logger

            NAME = 'CodebaseSearch'
            DESCRIPTION = 'Performs a semantic search on the codebase'
            EXAMPLE = 'Codebase Search Tool example'

            ACTIVE_CONTEXT_QUERY_CLASS = ::Ai::ActiveContext::Queries::Code

            PROJECT_GLOBAL_ID_PATTERN = %r{gid://gitlab/Project/(\d+)}

            def perform
              return no_repository_contexts_answer unless has_repository_additional_context?

              log_semantic_search_requesting

              enhance_repository_context

              log_semantic_search_requested

              successful_answer
            rescue StandardError => e
              error_message = "Error in semantic search: #{e.class} #{e.message}"

              log_event_error(error_message)

              Answer.new(status: :error, context: context, content: error_message, tool: nil)
            end

            def authorize
              Utils::ChatAuthorizer.user(user: context.current_user).allowed?
            end

            def unit_primitive
              'codebase_search'
            end

            private

            def has_repository_additional_context?
              repository_project_global_ids.present?
            end

            def repository_project_global_ids
              @repository_project_global_ids ||= context.additional_context.filter_map do |ctx|
                ctx[:category] == 'repository' ? ctx[:id] : nil
              end
            end

            def enhance_repository_context
              codebase_query = ACTIVE_CONTEXT_QUERY_CLASS.new(search_term: options[:input], user: context.current_user)

              context.additional_context.each do |ctx|
                next unless ctx[:category] == 'repository'

                project_id = extract_project_id_from_global_id(ctx[:id])
                next unless project_id

                results = codebase_query.filter(project_id: project_id)

                ctx[:content] += "\n\n" \
                  "A semantic search has been performed on the repository. " \
                  "The results are listed below enclosed in <search_result></search_result>. " \
                  "Each result has a file_path and content. The content may be a snippet " \
                  "within the file or the full file content.\n\n"
                ctx[:content] += results.map do |r|
                  "<search_result>\n" \
                    "<file_path>#{r['path']}</file_path>\n" \
                    "<content>#{r['content']}</content>\n" \
                    "</search_result>"
                end.join("\n\n")
              end
            end

            def extract_project_id_from_global_id(project_global_id)
              match_data = PROJECT_GLOBAL_ID_PATTERN.match(project_global_id)
              return unless match_data && match_data[1]

              match_data[1].to_i
            end

            def log_semantic_search_requesting
              message = "Requesting semantic search for \"#{options[:input]}\" " \
                "on projects #{repository_project_global_ids}"

              log_event_info(
                name: 'requesting',
                message: message
              )
            end

            def log_semantic_search_requested
              message = "Semantic search requested for \"#{options[:input]}\" " \
                "on projects #{repository_project_global_ids}"

              log_event_info(
                name: 'requested',
                message: message
              )
            end

            def log_event_info(name:, message:)
              log_info(
                event_name: event_name(name),
                message: message,
                unit_primitive: unit_primitive,
                ai_component: 'duo_chat'
              )
            end

            def log_event_error(error_message)
              log_error(
                message: error_message,
                event_name: event_name('failed'),
                unit_primitive: unit_primitive,
                ai_component: 'duo_chat'
              )
            end

            def event_name(name)
              "#{unit_primitive}_#{name}"
            end

            def successful_answer
              message = "The repository additional contexts have been enhanced with semantic search results."
              Answer.new(status: :ok, context: context, content: message, tool: nil)
            end

            def no_repository_contexts_answer
              message = "There are no repository additional contexts. Semantic search was not executed."
              Answer.new(status: :not_executed, context: context, content: message, tool: nil)
            end
          end
        end
      end
    end
  end
end
