# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::AiGatewaySelfHostedMessages, feature_category: :"self-hosted_models" do
  let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :self_hosted) }

  let(:prompt_version) { 2 }

  let(:suffix) do
    <<~SUFFIX
      def use_binary_search
      end
    SUFFIX
  end

  let(:comment) { 'Generate a binary search method.' }
  let(:instruction) { instance_double(CodeSuggestions::Instruction, instruction: comment, trigger_type: 'comment') }

  let(:params) do
    {
      instruction: instruction
    }
  end

  subject(:prompt) { described_class.new(feature_setting: feature_setting, params: params) }

  describe '#request_params' do
    let(:request_params) do
      {
        model_provider: described_class::MODEL_PROVIDER,
        model_name: feature_setting.self_hosted_model.model,
        prompt_version: prompt_version,
        model_endpoint: feature_setting.self_hosted_model.endpoint,
        model_api_key: feature_setting.self_hosted_model.api_token,
        prompt_id: described_class::PROMPT_ID
      }
    end

    it 'returns expected request params with instruction' do
      expect(prompt.request_params).to eq(request_params.merge(prompt: comment))
    end

    context 'when instruction is missing' do
      let(:instruction) { nil }

      it 'sends an empty instruction' do
        expect(prompt.request_params).to eq(
          request_params.merge(prompt: "")
        )
      end
    end
  end
end
