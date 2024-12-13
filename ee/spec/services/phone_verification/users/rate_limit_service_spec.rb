# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PhoneVerification::Users::RateLimitService, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build(:user) }

  describe 'daily transactions limit exceeded checks' do
    shared_examples 'it returns the correct result' do |rate_limit_name|
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:peek).with(rate_limit_name, scope: nil).and_return(exceeded)
      end

      context 'when limit has been exceeded' do
        let(:exceeded) { true }

        it { is_expected.to eq true }
      end

      context 'when limit has not been exceeded' do
        let(:exceeded) { false }

        it { is_expected.to eq false }
      end
    end

    describe '.daily_transaction_soft_limit_exceeded?' do
      subject(:result) { described_class.daily_transaction_soft_limit_exceeded? }

      it_behaves_like 'it returns the correct result',
        :soft_phone_verification_transactions_limit
    end

    describe '.daily_transaction_hard_limit_exceeded?' do
      subject(:result) { described_class.daily_transaction_hard_limit_exceeded? }

      it_behaves_like 'it returns the correct result',
        :hard_phone_verification_transactions_limit
    end
  end

  describe '.increase_daily_attempts' do
    with_them do
      subject(:increase_attempts) { described_class.increase_daily_attempts }

      def expect_throttled_called(key)
        expect(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).with(key, scope: nil)
      end

      def expect_throttled_not_called(key)
        expect(::Gitlab::ApplicationRateLimiter).not_to receive(:throttled?).with(key, scope: nil)
      end

      it 'calls throttled? with the correct keys' do
        expect_throttled_called(:soft_phone_verification_transactions_limit)

        expect_throttled_called(:hard_phone_verification_transactions_limit)
        increase_attempts
      end
    end
  end

  describe '.assume_user_high_risk_if_daily_limit_exceeded!' do
    let(:limit_exceeded) { true }

    subject(:call_method) { described_class.assume_user_high_risk_if_daily_limit_exceeded!(user) }

    before do
      allow(described_class).to receive(:daily_transaction_soft_limit_exceeded?).and_return(limit_exceeded)
    end

    it 'calls assume_high_risk! on the user' do
      expect(user).to receive(:assume_high_risk!).with(reason: 'Phone verification daily transaction limit exceeded')

      call_method
    end

    context 'when limit has not been exceeded' do
      let(:limit_exceeded) { false }

      it 'does not call assume_high_risk! on the user' do
        expect(user).not_to receive(:assume_high_risk!)

        call_method
      end
    end
  end
end
