# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      class Completions
        def initialize(user, organization:, resource: nil)
          @current_user = user
          @resource = resource
          @organization = organization
        end

        def execute(safe_params: {})
          action_name = 'chat'

          thread = Gitlab::Llm::ThreadEnsurer.new(current_user, organization).execute(
            conversation_type: :duo_chat_legacy,
            write_mode: true
          )

          options = safe_params.slice(:referer_url, :current_file, :additional_context).compact_blank
          message_attributes = {
            request_id: SecureRandom.uuid,
            role: ::Gitlab::Llm::AiMessage::ROLE_USER,
            ai_action: action_name,
            user: current_user,
            thread: thread,
            context: ::Gitlab::Llm::AiMessageContext.new(resource: resource),
            client_subscription_id: safe_params[:client_subscription_id],
            additional_context: ::Gitlab::Llm::AiMessageAdditionalContext.new(safe_params[:additional_context])
          }

          reset_chat(action_name, message_attributes) if safe_params[:with_clean_history]

          message_attributes[:content] = safe_params[:content]

          prompt_message = ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
          prompt_message.save!

          ai_response = ::Llm::Internal::CompletionService.new(prompt_message, options).execute

          reset_chat(action_name, message_attributes) if safe_params[:with_clean_history]

          ai_response
        end

        private

        attr_reader :current_user, :resource, :organization

        def reset_chat(action_name, message_attributes)
          message_attributes[:content] = '/reset'
          prompt_message = ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
          prompt_message.save!
        end
      end
    end
  end
end
