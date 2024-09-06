# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSetting, feature_category: :"self-hosted_models" do
  subject { build(:ai_feature_setting) }

  it { is_expected.to belong_to(:self_hosted_model) }
  it { is_expected.to validate_presence_of(:feature) }
  it { is_expected.to validate_uniqueness_of(:feature).ignoring_case_sensitivity }
  it { is_expected.to validate_presence_of(:provider) }

  context 'when feature setting is self hosted' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it { expect(feature_setting).to validate_presence_of(:self_hosted_model) }
    it { expect(feature_setting.provider_title).to eq('Self-hosted model (mistral-7b-ollama-api)') }
  end

  context 'when feature setting is vendored' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :vendored) }

    it { expect(feature_setting.provider_title).to eq('AI vendor') }
  end

  context 'when feature setting is disabled' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :disabled) }

    it { expect(feature_setting.provider_title).to eq('Disabled') }
  end

  describe '#code_suggestions_self_hosted?' do
    where(:feature, :provider, :code_suggestions_self_hosted) do
      [
        [:code_generations, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:code_completions, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:duo_chat, :self_hosted, false]
      ]
    end

    with_them do
      it 'returns whether code generations or completions are self hosted' do
        create(:ai_feature_setting, feature: feature, provider: provider)

        expect(described_class.code_suggestions_self_hosted?).to eq(code_suggestions_self_hosted)
      end
    end
  end

  describe '.feature_flagged_features' do
    let_it_be(:stable_features) { Ai::FeatureSetting::STABLE_FEATURES.dup.stringify_keys }
    let_it_be(:feature_flagged_features) { Ai::FeatureSetting::FLAGGED_FEATURES.dup.stringify_keys }

    context 'when ai_duo_chat_sub_features_settings FF is disabled' do
      before do
        stub_feature_flags(ai_duo_chat_sub_features_settings: false)
      end

      it 'returns only stable features' do
        expect(described_class.allowed_features).to eq(stable_features)
      end

      it 'does not include flagged features' do
        expect(described_class.allowed_features.keys).not_to include(*feature_flagged_features.keys)
      end
    end

    context 'when ai_duo_chat_sub_features_settings feature is enabled' do
      it 'returns both stable and flagged features' do
        expect(described_class.allowed_features).to eq(stable_features.merge(feature_flagged_features))
      end
    end
  end
end
