# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        # TODO: Rename to Gitlab::Duo::Chat::MultiStepExecutor
        class SingleActionExecutor
          include Gitlab::Utils::StrongMemoize
          include Langsmith::RunHelpers

          ToolNotFoundError = Class.new(StandardError)
          EmptyEventsError = Class.new(StandardError)
          ExhaustedLoopError = Class.new(StandardError)

          attr_reader :tools, :user_input, :context, :response_handler
          attr_accessor :iterations

          MAX_ITERATIONS = 10

          # @param [String] user_input - a question from a user
          # @param [Array<Tool>] tools - an array of Tools defined in the tools module.
          # @param [GitlabContext] context - Gitlab context containing useful context information
          # @param [ResponseService] response_handler - Handles returning the response to the client
          # @param [ResponseService] stream_response_handler - Handles streaming chunks to the client
          def initialize(user_input:, tools:, context:, response_handler:, stream_response_handler: nil)
            @user_input = user_input
            @tools = tools
            @context = context
            @iterations = 0
            @logger = Gitlab::Llm::Logger.build
            @response_handler = response_handler
            @stream_response_handler = stream_response_handler
          end

          def execute
            MAX_ITERATIONS.times do
              events = step_forward

              raise EmptyEventsError if events.empty?

              answer = process_final_answer(events) ||
                process_tool_action(events) ||
                process_unknown(events)

              return answer if answer
            end

            raise ExhaustedLoopError
          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error)
            error_answer(error)
          end
          traceable :execute, name: 'Run ReAct'

          private

          # TODO: Improve these error messages. See https://gitlab.com/gitlab-org/gitlab/-/issues/479465
          # TODO Handle ForbiddenError, ClientError, ServerError.
          def error_answer(error)
            case error
            when Net::ReadTimeout
              Answer.error_answer(
                error: error,
                context: context,
                content: _("I'm sorry, I couldn't respond in time. Please try again."),
                error_code: "A1000"
              )
            when Gitlab::Llm::AiGateway::Client::ConnectionError
              Answer.error_answer(
                error: error,
                context: context,
                error_code: "A1001"
              )
            when EmptyEventsError
              Answer.error_answer(
                error: error,
                context: context,
                content: _("I'm sorry, I couldn't respond in time. Please try again."),
                error_code: "A1002"
              )
            when ExhaustedLoopError
              Answer.default_final_answer(context: context)
            else
              Answer.error_answer(
                error: error,
                context: context,
                error_code: "A9999"
              )
            end
          end

          def process_final_answer(events)
            events = events.select { |e| e.instance_of? Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta }

            return if events.empty?

            content = events.map(&:text).join("")
            Answer.final_answer(context: context, content: content)
          end

          def process_tool_action(events)
            event = events.find { |e| e.instance_of? Gitlab::Duo::Chat::AgentEvents::Action }

            return unless event

            tool_class = get_tool_class(event.tool)

            tool = tool_class.new(
              context: context,
              options: {
                input: user_input,
                suggestions: event.thought
              },
              stream_response_handler: stream_response_handler
            )

            tool_answer = tool.execute

            return tool_answer if tool_answer.is_final?

            step_executor.update_observation(tool_answer.content.strip)

            nil
          end

          def process_unknown(events)
            event = events.find { |e| e.instance_of? Gitlab::Duo::Chat::AgentEvents::Unknown }

            return unless event

            logger.warn(message: "Surface an unknown event as a final answer to the user")

            Answer.final_answer(context: context, content: event.text)
          end

          def step_executor
            @step_executor ||= Gitlab::Duo::Chat::StepExecutor.new(context.current_user)
          end

          def step_forward
            streamed_answer = Gitlab::Llm::Chain::StreamedAnswer.new

            step_executor.step(step_params) do |event|
              next unless stream_response_handler
              next unless event.instance_of? Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta

              chunk = streamed_answer.next_chunk(event.text)

              next unless chunk

              stream_response_handler.execute(
                response: Gitlab::Llm::Chain::StreamedResponseModifier
                            .new(chunk[:content], chunk_id: chunk[:id]),
                options: { chunk_id: chunk[:id] }
              )
            end
          end

          def step_params
            {
              prompt: user_input,
              options: {
                chat_history: conversation,
                context: current_resource_params,
                current_file: current_file_params,
                additional_context: context.additional_context
              },
              model_metadata: model_metadata_params,
              unavailable_resources: unavailable_resources_params
            }
          end

          def get_tool_class(tool)
            tool_name = tool.camelize
            tool_class = tools.find { |tool_class| tool_class::Executor::NAME == tool_name }

            unless tool_class
              # Make sure that the v2/chat/agent endpoint in AI Gateway and the GitLab-Rails are compatible.
              logger.error(message: "Failed to find a tool in GitLab Rails", tool_name: tool_name)
              raise ToolNotFoundError, tool: tool_name
            end

            tool_class::Executor
          end

          def unavailable_resources_params
            resources = %w[Pipelines Vulnerabilities]
            resources << 'Merge Requests' unless Feature.enabled?(:ai_merge_request_reader_for_chat,
              context.current_user)

            resources
          end

          attr_reader :logger, :stream_response_handler

          def model_metadata_params
            return unless chat_feature_setting&.self_hosted?

            self_hosted_model = chat_feature_setting.self_hosted_model

            {
              provider: :openai, # for self-hosted models we support Messages API format at the moment
              name: self_hosted_model.model,
              endpoint: self_hosted_model.endpoint,
              api_key: self_hosted_model.api_token
            }
          end

          def conversation
            Utils::ChatConversation.new(context.current_user)
              .truncated_conversation_list
          end

          def current_resource_params
            return unless current_resource_type

            {
              type: current_resource_type,
              content: current_resource_content
            }
          end

          def current_resource_type
            context.current_page_type
          rescue ArgumentError
            nil
          end
          strong_memoize_attr :current_resource_type

          def current_resource_content
            context.current_page_short_description
          rescue ArgumentError
            nil
          end
          strong_memoize_attr :current_resource_content

          def current_file_params
            return unless current_selection || current_blob

            if current_selection
              file_path = current_selection[:file_name]
              data = current_selection[:selected_text]
            else
              file_path = current_blob.path
              data = current_blob.data
            end

            {
              file_path: file_path,
              data: data,
              selected_code: !!current_selection
            }
          end

          def current_selection
            return unless context.current_file[:selected_text].present?

            context.current_file
          end
          strong_memoize_attr :current_selection

          def current_blob
            context.extra_resource[:blob]
          end
          strong_memoize_attr :current_blob

          def chat_feature_setting
            ::Ai::FeatureSetting.find_by_feature(:duo_chat)
          end
        end
      end
    end
  end
end
