# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails, feature_category: :code_suggestions do
  let_it_be(:feature_setting_name) { 'code_completions' }
  let(:user) { create(:user) }
  let(:completions_model_details) do
    described_class.new(current_user: user, feature_setting_name: feature_setting_name)
  end

  describe '#feature_disabled?' do
    subject(:feature_disabled?) { completions_model_details.feature_disabled? }

    it 'returns false' do
      expect(feature_disabled?).to be(false)
    end

    context 'when the feature is self-hosted, but set to disabled' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, provider: :disabled, feature: feature_setting_name)
      end

      it 'returns true' do
        expect(feature_disabled?).to be(true)
      end
    end
  end

  describe '#base_url' do
    it 'returns correct URL' do
      expect(completions_model_details.base_url).to eql('https://cloud.gitlab.com/ai')
    end

    context 'when the feature is customized' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored) }

      it 'takes the base url from feature settings' do
        url = "http://localhost:5000"
        expect(::Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(url)

        expect(completions_model_details.base_url).to eq(url)
      end
    end
  end
end
