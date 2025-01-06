# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::CodeCompletion, feature_category: :code_suggestions do
  let(:user) { create(:user) }
  let(:completions_model_details) { described_class.new(current_user: user) }

  describe '#current_model' do
    subject(:model_details) { completions_model_details.current_model }

    context 'when fireworks qwen FF is enabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: true)
      end

      it 'returns the correct code completions model metadata' do
        expected_medata = {
          model_provider: 'fireworks_ai',
          model_name: 'qwen2p5-coder-7b'
        }

        expect(model_details).to eq(expected_medata)
      end
    end

    context 'when code completions FFs are disabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: false)
      end

      it 'returns an empty hash' do
        expect(model_details).to eq({})
      end
    end

    context 'when code_completions is self-hosted' do
      before do
        feature_setting_double = instance_double(::Ai::FeatureSetting, self_hosted?: true)
        allow(::Ai::FeatureSetting).to receive(:find_by_feature).with('code_completions')
          .and_return(feature_setting_double)
      end

      it 'returns an empty hash' do
        expect(model_details).to eq({})
      end
    end
  end

  describe '#saas_primary_model_class' do
    subject(:model_class) { completions_model_details.saas_primary_model_class }

    let(:fireworks_qwen_model_class) { CodeSuggestions::Prompts::CodeCompletion::FireworksQwen }
    let(:codegecko_model_class) { CodeSuggestions::Prompts::CodeCompletion::VertexAi }

    context 'when Fireworks/Qwen beta FF is enabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: true)
      end

      it 'returns the fireworks/qwen model class' do
        expect(model_class).to eq(fireworks_qwen_model_class)
      end
    end

    context 'when Fireworks/Qwen beta FF is disabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: false)
      end

      it 'returns the codegecko model class' do
        expect(model_class).to eq(codegecko_model_class)
      end
    end

    context 'when code_completions is self-hosted' do
      before do
        feature_setting_double = instance_double(::Ai::FeatureSetting, self_hosted?: true)
        allow(::Ai::FeatureSetting).to receive(:find_by_feature).with('code_completions')
          .and_return(feature_setting_double)
      end

      it 'returns nil' do
        expect(model_class).to be_nil
      end
    end
  end
end
