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

      def feature_setting_name
        :code_generations
      end

      def prompt
        if self_hosted?
          CodeSuggestions::Prompts::CodeGeneration::AiGatewaySelfHostedMessages.new(
            feature_setting: feature_setting, params: params)
        else
          CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages.new(params)
        end
      end

      strong_memoize_attr :prompt
    end
  end
end
