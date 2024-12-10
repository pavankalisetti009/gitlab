# frozen_string_literal: true

module CodeSuggestions
  class CompletionsModelDetails < ModelDetails
    FEATURE_SETTING_NAME = 'code_completions'

    def initialize(current_user:)
      super(current_user: current_user, feature_setting_name: FEATURE_SETTING_NAME)
    end

    def current_model
      # if self-hosted, the model details are provided by the client
      return {} if self_hosted?

      return fireworks_qwen_2_5_model_details if use_fireworks_qwen_for_code_completions?

      # the default behavior is returning an empty hash
      # AI Gateway will fall back to the code-gecko model if model details are not provided
      {}
    end

    private

    def fireworks_qwen_2_5_model_details
      {
        model_provider: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_PROVIDER,
        model_name: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_NAME
      }
    end

    def use_fireworks_qwen_for_code_completions?
      Feature.enabled?(:fireworks_qwen_code_completion, current_user, type: :beta)
    end
  end
end
