# frozen_string_literal: true

module Gitlab
  module Llm
    module Completions
      class GenerateCommitMessage < Gitlab::Llm::Completions::Base
        include ::Gitlab::Llm::Concerns::AvailableModels

        DEFAULT_ERROR = 'An unexpected error has occurred.'

        def execute
          response = response_for(user, merge_request)
          response_modifier = modify_response(response)

          ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
            user, merge_request, response_modifier, options: response_options
          ).execute
        rescue StandardError => error
          Gitlab::ErrorTracking.track_exception(error)

          response_modifier = modify_response(
            { error: { message: DEFAULT_ERROR } }.to_json
          )

          ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
            user, merge_request, response_modifier, options: response_options
          ).execute

          response_modifier
        end

        private

        def anthropic?
          Feature.enabled?(:generate_commit_message_anthropic, merge_request.project, type: :beta)
        end

        def merge_request
          resource
        end

        def modify_response(response)
          if anthropic?
            ::Gitlab::Llm::Anthropic::ResponseModifiers::GenerateCommitMessage.new(response)
          else
            ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(response)
          end
        end

        def response_for(user, merge_request)
          if anthropic?
            @ai_prompt_class = ::Gitlab::Llm::Templates::GenerateCommitMessageAnthropic
            template = ai_prompt_class.new(merge_request)

            Gitlab::Llm::Anthropic::Client
              .new(user, unit_primitive: 'generate_commit_message', tracking_context: tracking_context)
              .messages_complete(**template.to_prompt)
          else
            template = ai_prompt_class.new(merge_request)

            ::Gitlab::Llm::VertexAi::Client
              .new(user, unit_primitive: 'generate_commit_message', tracking_context: tracking_context)
              .text(content: template.to_prompt)
          end
        end
      end
    end
  end
end
