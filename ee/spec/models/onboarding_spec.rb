# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let(:user) { build_stubbed(:user) }

  describe '.user_onboarding_in_progress?' do
    where(
      user?: [true, false],
      user_onboarding?: [true, false],
      onboarding?: [true, false]
    )

    with_them do
      let(:local_user) { user? ? user : nil }
      let(:expected_result) { user_onboarding? && user? && onboarding? }

      before do
        allow(user).to receive(:onboarding_in_progress?).and_return(user_onboarding?)
        stub_saas_features(onboarding: onboarding?)
      end

      subject { described_class.user_onboarding_in_progress?(local_user) }

      it { is_expected.to be expected_result }
    end
  end

  describe '.enabled?' do
    subject { described_class.enabled? }

    context 'when onboarding feature is available' do
      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to eq(true) }
    end

    context 'when onboarding feature is not available' do
      it { is_expected.to eq(false) }
    end
  end
end
