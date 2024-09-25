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
          # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Global development flag for migrating the prompts
          if ::Feature.enabled?(:ai_custom_models_prompts_migration)
            return CodeSuggestions::Prompts::CodeGeneration::AiGatewaySelfHostedMessages.new(
              feature_setting: feature_setting, params: params)
          end
          # rubocop:enable Gitlab/FeatureFlagWithoutActor

          model_name = feature_setting&.self_hosted_model&.model&.to_sym
          case model_name
          when :codellama
            CodeSuggestions::Prompts::CodeGeneration::CodellamaMessages.new(
              feature_setting: feature_setting, params: params)
          when :mistral, :mixtral, :mixtral_8x22b, :codestral, :codegemma
            CodeSuggestions::Prompts::CodeGeneration::MistralMessages.new(
              feature_setting: feature_setting, params: params)
          else
            raise "Unknown model: #{model_name}"
          end
        elsif ::Feature.enabled?(:anthropic_code_gen_aigw_migration, current_user)
          CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages.new(params)
        else
          CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages.new(params)
        end
      end

      strong_memoize_attr :prompt
    end
  end
end
