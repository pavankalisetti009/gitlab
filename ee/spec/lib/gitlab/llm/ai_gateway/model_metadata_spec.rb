# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ModelMetadata, feature_category: :ai_abstraction_layer do
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:self_hosted_feature_setting) { create(:ai_feature_setting, self_hosted_model: self_hosted_model) }

  let(:feature_setting) { self_hosted_feature_setting }
  let(:model_metadata) { described_class.new(feature_setting: feature_setting) }

  describe '#to_params' do
    subject(:to_params) { model_metadata.to_params }

    context 'when feature_setting is self-hosted' do
      it 'returns self-hosted params' do
        is_expected.to eq({
          provider: self_hosted_model.provider,
          name: self_hosted_model.model,
          endpoint: self_hosted_model.endpoint,
          api_key: self_hosted_model.api_token,
          identifier: self_hosted_model.identifier
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is connected' do
      let(:feature_setting) { nil }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        ::Ai::Setting.instance.update!(amazon_q_role_arn: "role-arn")
      end

      it 'returns amazon_q params' do
        is_expected.to eq({
          provider: :amazon_q,
          name: :amazon_q,
          role_arn: "role-arn"
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is not connected' do
      let(:feature_setting) { nil }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#self_hosted_params' do
    let(:model_metadata) { described_class.new(feature_setting: feature_setting) }

    subject(:self_hosted_params) { model_metadata.self_hosted_params }

    context 'when feature is nil' do
      let(:feature_setting) { nil }

      it { is_expected.to be_nil }
    end

    context 'when feature is not self_hosted' do
      before do
        allow(feature_setting).to receive(:self_hosted_model).and_return(nil)
      end

      it { is_expected.to be_nil }
    end

    context 'when feature is self_hosted' do
      it 'returns model configuration' do
        is_expected.to eq({
          api_key: "token",
          endpoint: "http://localhost:11434/v1",
          identifier: "provider/some-model",
          name: "mistral",
          provider: :openai
        })
      end
    end
  end
end
