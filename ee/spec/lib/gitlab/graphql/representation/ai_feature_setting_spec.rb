# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Representation::AiFeatureSetting, feature_category: :"self-hosted_models" do
  let(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :vendored) }

  let(:feature_settings) { [feature_setting] }

  let :model_params do
    [
      { name: 'ollama-codellama', model: :codellama },
      { name: 'vllm-codegemma', model: :codegemma, api_token: "test_api_token" },
      { name: 'vllm-mistral', model: :mistral }
    ]
  end

  let :self_hosted_models do
    model_params.map { |params| create(:ai_self_hosted_model, **params) }
  end

  let :expected_valid_models do
    valid_model_names = %w[vllm-mistral]

    self_hosted_models
      .select { |m| valid_model_names.include?(m.name) }
  end

  describe '.decorate' do
    context 'when feature_settings is nil' do
      it 'returns nil' do
        expect(described_class.decorate(nil)).to eq []
      end
    end

    context 'when feature_settings is present' do
      it 'returns an array of decorated objects' do
        result = described_class.decorate(feature_settings)
        expect(result).to all(be_a(described_class))
      end

      context 'when with_valid_models is true' do
        it 'calls decorate_with_valid_models' do
          expect(described_class).to receive(:decorate_with_valid_models).with(feature_settings)
          described_class.decorate(feature_settings, with_valid_models: true)
        end
      end

      context 'when with_valid_models is false' do
        it 'calls decorate_with_valid_models' do
          expect(described_class).not_to receive(:decorate_with_valid_models)
          described_class.decorate(feature_settings, with_valid_models: false)
        end
      end
    end
  end

  describe '.decorate_with_valid_models' do
    before do
      allow(::Ai::SelfHostedModel).to receive(:all).and_return(self_hosted_models)
    end

    it 'returns an array of decorated objects with valid models' do
      result = described_class.decorate_with_valid_models(feature_settings)
      expect(result.first.valid_models).to match_array(expected_valid_models)
    end
  end

  describe '#initialize' do
    it 'sets the feature_setting and valid_models', :aggregate_failures do
      decorated = described_class.new(feature_setting, valid_models: self_hosted_models)

      expect(decorated.valid_models).to eq(self_hosted_models)
      expect(decorated.__getobj__).to eq(feature_setting)
    end

    it 'defaults valid_models to an empty array' do
      decorated = described_class.new(feature_setting)
      expect(decorated.valid_models).to eq([])
    end
  end
end
