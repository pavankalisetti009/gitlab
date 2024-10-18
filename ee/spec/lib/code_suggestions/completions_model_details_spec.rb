# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::CompletionsModelDetails, feature_category: :code_suggestions do
  let(:user) { create(:user) }
  let(:completions_model_details) { described_class.new(current_user: user) }

  describe '#current_model' do
    subject(:model_details) { completions_model_details.current_model }

    it 'returns the current code completions model metadata' do
      expected_medata = {
        model_provider: 'vertex-ai',
        model_name: 'codestral@2405'
      }

      expect(model_details).to eq(expected_medata)
    end

    context 'when use_codestral_for_code_completions FF is disabled' do
      before do
        stub_feature_flags(use_codestral_for_code_completions: false)
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

  describe '#feature_disabled?' do
    subject(:feature_disabled?) { completions_model_details.feature_disabled? }

    it 'returns false' do
      expect(feature_disabled?).to eq(false)
    end

    context 'when code_completions is self-hosted, but set to disabled' do
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, provider: :disabled, feature: :code_completions)
      end

      it 'returns true' do
        expect(feature_disabled?).to eq(true)
      end
    end
  end
end
