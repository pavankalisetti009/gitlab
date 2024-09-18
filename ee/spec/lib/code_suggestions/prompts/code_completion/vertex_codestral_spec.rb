# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::VertexCodestral, feature_category: :code_suggestions do
  subject(:vertex_codestral_prompt) { described_class.new({}) }

  describe '#request_params' do
    it 'returns expected request params' do
      request_params = {
        prompt_version: 1,
        model_name: "codestral@2405",
        model_provider: "vertex-ai"
      }
      expect(vertex_codestral_prompt.request_params).to eq(request_params)
    end
  end
end
