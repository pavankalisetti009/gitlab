# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        class SingleActionExecutor
          include Gitlab::Utils::StrongMemoize
          include Concerns::AiDependent
          include Langsmith::RunHelpers

          attr_reader :tools, :user_input, :context, :response_handler
          attr_accessor :iterations

          MAX_ITERATIONS = 10
          RESPONSE_TYPE_TOOL = 'tool'

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
            @agent_scratchpad = []
            MAX_ITERATIONS.times do
              step = {}
              thoughts = execute_streamed_request

              answer = Answer.from_response(
                response_body: thoughts,
                tools: tools,
                context: context,
                parser_klass: Parsers::SingleActionParser
              )

              return answer if answer.is_final?

              step[:thought] = answer.suggestions
              step[:tool] = answer.tool
              step[:tool_input] = user_input

              tool_class = answer.tool

              tool = tool_class.new(
                context: context,
                options: {
                  input: user_input,
                  suggestions: answer.suggestions
                },
                stream_response_handler: stream_response_handler
              )

              tool_answer = tool.execute

              return tool_answer if tool_answer.is_final?

              step[:observation] = tool_answer.content.strip
              @agent_scratchpad.push(step)
            end

            Answer.default_final_answer(context: context)
          rescue Net::ReadTimeout => error
            Gitlab::ErrorTracking.track_exception(error)
            Answer.error_answer(
              error: error,
              context: context,
              content: _("I'm sorry, I couldn't respond in time. Please try again."),
              error_code: "A1000"
            )
          rescue Gitlab::Llm::AiGateway::Client::ConnectionError => error
            Gitlab::ErrorTracking.track_exception(error)
            Answer.error_answer(
              error: error,
              context: context,
              error_code: "A1001"
            )
          end
          traceable :execute, name: 'Run ReAct'

          private

          def streamed_content(_content, chunk)
            chunk[:content]
          end

          def execute_streamed_request
            request(&streamed_request_handler(Answers::StreamedJson.new))
          end

          attr_reader :logger, :stream_response_handler

          # This method should not be memoized because the input variables change over time
          def prompt
            { prompt: user_input, options: prompt_options }
          end

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

          def prompt_options
            @options = {
              agent_scratchpad: @agent_scratchpad,
              conversation: conversation,
              current_resource_params: current_resource_params,
              current_file_params: current_file_params,
              model_metadata: model_metadata_params,
              single_action_agent: true,
              additional_context: context.additional_context
            }
          end

          def conversation
            Utils::ChatConversation.new(context.current_user)
              .truncated_conversation_list
              .join(", ")
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
