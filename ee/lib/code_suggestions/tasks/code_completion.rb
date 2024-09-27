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
          CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
            feature_setting: feature_setting, params: params)
        elsif Feature.enabled?(:use_codestral_for_code_completions, current_user, type: :beta)
          # codestral hosted on vertex
          CodeSuggestions::Prompts::CodeCompletion::VertexCodestral.new(params)
        else
          # codegecho hosted on vertex
          CodeSuggestions::Prompts::CodeCompletion::VertexAi.new(params)
        end
      end

      strong_memoize_attr :prompt
    end
  end
end
