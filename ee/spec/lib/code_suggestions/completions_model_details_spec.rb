# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::CompletionsModelDetails, feature_category: :code_suggestions do
  describe '#current_model' do
    let(:user) { create(:user) }
    let(:completions_model_details) { described_class.new(current_user: user) }

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
end
