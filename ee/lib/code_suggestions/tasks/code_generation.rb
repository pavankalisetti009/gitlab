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
        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages.new(params, current_user, feature_setting)
      end

      strong_memoize_attr :prompt
    end
  end
end
