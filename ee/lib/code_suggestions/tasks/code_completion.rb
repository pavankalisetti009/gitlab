# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeCompletion < Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      delegate :saas_primary_model_class, to: :model_details

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      private

      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::CodeCompletion.new(current_user: current_user)
      end

      def prompt
        if self_hosted?
          self_hosted_prompt
        else
          saas_prompt
        end
      end
      strong_memoize_attr :prompt

      def self_hosted_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
          feature_setting: feature_setting, params: params)
      end

      def saas_prompt
        if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
          # claude hosted on anthropic
          CodeSuggestions::Prompts::CodeCompletion::Anthropic.new(params)
        else
          saas_primary_model_class.new(params)
        end
      end
    end
  end
end
