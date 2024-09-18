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
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Global development flag for migrating the prompts
          if ::Feature.enabled?(:ai_custom_models_prompts_migration)
            return CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
              feature_setting: feature_setting, params: params)
          end
          # rubocop:enable Gitlab/FeatureFlagWithoutActor

          model_name = feature_setting&.self_hosted_model&.model&.to_sym
          case model_name
          when :codegemma_2b, :codegemma_7b
            CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages.new(
              feature_setting: feature_setting, params: params)
          when :codestral
            CodeSuggestions::Prompts::CodeCompletion::CodestralMessages.new(
              feature_setting: feature_setting, params: params)
          when :codellama_13b_code
            CodeSuggestions::Prompts::CodeCompletion::CodellamaMessages.new(
              feature_setting: feature_setting, params: params)
          else
            raise "Unknown model: #{model_name}"
          end
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
