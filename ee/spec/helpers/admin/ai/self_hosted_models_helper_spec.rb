# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::Ai::SelfHostedModelsHelper, feature_category: :"self-hosted_models" do
  describe '#model_choices_as_options' do
    it 'returns an array of hashes with model options sorted alphabetically' do
      expected_result = [
        { modelValue: "CLAUDE_3", modelName: "Claude 3" },
        { modelValue: "CODELLAMA", modelName: "Code Llama" },
        { modelValue: "CODEGEMMA", modelName: "CodeGemma" },
        { modelValue: "DEEPSEEKCODER", modelName: "DeepSeek Coder" },
        { modelValue: "GPT", modelName: "GPT" },
        { modelValue: "LLAMA3", modelName: "Llama 3" },
        { modelValue: "MISTRAL", modelName: "Mistral" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral" },
        { modelValue: "MIXTRAL", modelName: "Mixtral" }
      ]

      expect(helper.model_choices_as_options).to eq(expected_result)
    end

    it 'humanizes the model name when there is no mapped name available' do
      allow(::Ai::SelfHostedModel).to receive(:models).and_return(["unmapped_model"])

      expect(helper.model_choices_as_options).to eq([
        {
          modelValue: "UNMAPPED_MODEL",
          modelName: "Unmapped model"
        }
      ])
    end
  end
end
