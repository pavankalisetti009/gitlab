# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeCompletion < Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      private

      def feature_setting_name
        :code_completions
      end

      def prompt
        if self_hosted?
          self_hosted_prompt
        else
          saas_prompt
        end
      end

      def self_hosted_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
          feature_setting: feature_setting, params: params)
      end

      def saas_prompt
        if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
          # claude hosted on anthropic
          CodeSuggestions::Prompts::CodeCompletion::Anthropic.new(params)
        elsif Feature.enabled?(:fireworks_qwen_code_completion, current_user, type: :beta)
          # qwen 2.5 hosted on fireworks
          CodeSuggestions::Prompts::CodeCompletion::FireworksQwen.new(params)
        else
          # codegecho hosted on vertex
          CodeSuggestions::Prompts::CodeCompletion::VertexAi.new(params)
        end
      end

      strong_memoize_attr :prompt
    end
  end
end
