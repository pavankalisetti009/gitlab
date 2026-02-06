# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::ModelSelector, feature_category: :code_suggestions do
  describe '.use_gitlab_selected_model?' do
    subject(:use_gitlab_selected_model) { described_class.use_gitlab_selected_model? }

    context 'on saas instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
      end

      it { is_expected.to be(true) }
    end

    context 'on dedicated instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
      end

      it { is_expected.to be(true) }
    end

    context 'on SM instance without self-hosted AIGW' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
      end

      it { is_expected.to be(true) }
    end

    context 'on SM instance with self-hosted AIGW' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(true)
      end

      it { is_expected.to be(false) }
    end
  end
end
