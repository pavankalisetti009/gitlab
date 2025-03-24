# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeGeneration < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      override :endpoint_name
      def endpoint_name
        'generations'
      end

      private

      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::Base.new(
          current_user: current_user,
          feature_setting_name: :code_generations
        )
      end

      def prompt
        if Feature.enabled?(:amazon_q_chat_and_code_suggestions, current_user) && ::Ai::AmazonQ.connected?
          return amazon_q_prompt
        end

        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages.new(params, current_user, feature_setting)
      end

      def amazon_q_prompt
        CodeSuggestions::Prompts::CodeGeneration::AmazonQ.new(params, current_user)
      end

      strong_memoize_attr :prompt
    end
  end
end
