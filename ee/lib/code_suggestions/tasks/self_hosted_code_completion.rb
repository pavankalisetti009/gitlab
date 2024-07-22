# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class SelfHostedCodeCompletion < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      def initialize(feature_setting:, **kwargs)
        @feature_setting = feature_setting

        super(**kwargs)
      end

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      override :service_name
      def feature_name
        :self_hosted_models
      end

      private

      attr_reader :feature_setting

      def params
        self_hosted_model = feature_setting.self_hosted_model

        super.merge({
          model_name: self_hosted_model.model,
          model_endpoint: self_hosted_model.endpoint
        })
      end

      def prompt
        model_name = feature_setting.self_hosted_model.model.to_sym
        # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Global development flag for migrating the prompts
        prompt_migration_enabled = ::Feature.enabled?(:ai_custom_models_prompts_migration)
        # rubocop:enable Gitlab/FeatureFlagWithoutActor
        ai_gateway_class = CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage
        model_classes = {
          codegemma: CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages,
          codestral: CodeSuggestions::Prompts::CodeCompletion::CodestralMessages,
          'codellama:code': CodeSuggestions::Prompts::CodeCompletion::CodellamaMessages
        }

        message_class = if prompt_migration_enabled
                          ai_gateway_class
                        else
                          model_classes.fetch(model_name) { raise "Unknown model: #{model_name}" }
                        end

        message_class.new(params)
      end
      strong_memoize_attr :prompt
    end
  end
end
