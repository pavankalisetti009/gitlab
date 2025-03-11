# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ModelMetadata, feature_category: :ai_abstraction_layer do
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:feature_setting) { create(:ai_feature_setting, self_hosted_model: self_hosted_model) }

  describe '#to_params' do
    context 'when feature_setting is self-hosted' do
      it 'returns self-hosted params' do
        model_metadata = described_class.new(feature_setting: feature_setting)

        expect(model_metadata.to_params).to eq({
          provider: self_hosted_model.provider,
          name: self_hosted_model.model,
          endpoint: self_hosted_model.endpoint,
          api_key: self_hosted_model.api_token,
          identifier: self_hosted_model.identifier
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        ::Ai::Setting.instance.update!(amazon_q_role_arn: "role-arn")
      end

      it 'returns amazon_q params' do
        model_metadata = described_class.new

        expect(model_metadata.to_params).to eq({
          provider: :amazon_q,
          name: :amazon_q,
          role_arn: "role-arn"
        })
      end
    end

    context 'when feature_setting is not self-hosted and Ai::AmazonQ is not connected' do
      let(:self_hosted) { false }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
      end

      it 'returns nil' do
        model_metadata = described_class.new

        expect(model_metadata.to_params).to be_nil
      end
    end
  end
end
