# frozen_string_literal: true

module CodeSuggestions
  class CompletionsModelDetails
    FEATURE_SETTING_NAME = 'code_completions'

    def initialize(current_user:)
      @current_user = current_user
    end

    def current_model
      # if self-hosted, the model details are provided by the client
      return {} if self_hosted?

      return codestral_model_details if use_codestral_for_code_completions?

      # the default behavior is returning an empty hash
      # AI Gateway will fall back to the code-gecko model if model details are not provided
      {}
    end

    private

    attr_reader :current_user

    def codestral_model_details
      {
        model_provider: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_PROVIDER,
        model_name: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_NAME
      }
    end

    def self_hosted?
      feature_setting&.self_hosted?
    end

    def use_codestral_for_code_completions?
      Feature.enabled?(:use_codestral_for_code_completions, current_user, type: :beta)
    end

    def feature_setting
      @feature_setting ||= ::Ai::FeatureSetting.find_by_feature(FEATURE_SETTING_NAME)
    end
  end
end
