# frozen_string_literal: true

module Admin
  module Ai
    module SelfHostedModelsHelper
      MODEL_NAME_MAPPER = {
        "mistral" => "Mistral",
        "mixtral" => "Mixtral",
        "llama3" => "Llama 3",
        "codegemma" => "CodeGemma",
        "codestral" => "Mistral Codestral",
        "codellama" => "Code Llama",
        "deepseekcoder" => "DeepSeek Coder",
        "claude_3" => "Claude 3",
        "gpt" => "GPT"
      }.freeze

      def model_choices_as_options
        model_options =
          ::Ai::SelfHostedModel.models.map do |name, _|
            {
              modelValue: name.upcase,
              modelName: MODEL_NAME_MAPPER[name] || name.humanize
            }
          end

        model_options.sort_by { |option| option[:modelName] }
      end
    end
  end
end
