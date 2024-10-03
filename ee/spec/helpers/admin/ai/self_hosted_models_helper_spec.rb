# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::Ai::SelfHostedModelsHelper, feature_category: :"self-hosted_models" do
  describe '#model_choices_as_options' do
    it 'returns an array of hashes with model options' do
      expected_result = [
        { modelValue: "MISTRAL", modelName: "Mistral" },
        { modelValue: "LLAMA3", modelName: "Llama3" },
        { modelValue: "CODEGEMMA", modelName: "Codegemma" },
        { modelValue: "CODESTRAL", modelName: "Codestral" },
        { modelValue: "CODELLAMA", modelName: "Codellama" },
        { modelValue: "DEEPSEEKCODER", modelName: "Deepseekcoder" },
        { modelValue: "CLAUDE_3", modelName: "Claude 3" }
      ]

      expect(helper.model_choices_as_options).to match_array(expected_result)
    end
  end
end
