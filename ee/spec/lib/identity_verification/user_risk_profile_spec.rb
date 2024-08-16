# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdentityVerification::UserRiskProfile, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:risk_profile) { described_class.new(user) }

  describe '#assume_low_risk!' do
    subject(:call_method) { risk_profile.assume_low_risk!(reason: 'Because') }

    it 'creates a custom attribute with correct attribute values for the user', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'IdentityVerification::UserRiskProfile',
        event: 'User assumed low risk.',
        reason: 'Because',
        user_id: user.id,
        username: user.username
      )
      expect { call_method }.to change { user.custom_attributes.count }.by(1)

      record = user.custom_attributes.last
      expect(record.key).to eq described_class::ASSUMED_LOW_RISK_ATTR_KEY
      expect(record.value).to eq 'Because'
    end
  end

  describe '#assume_high_risk!' do
    subject(:call_method) { risk_profile.assume_high_risk!(reason: 'Because') }

    it 'creates a custom attribute with correct attribute values for the user', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'IdentityVerification::UserRiskProfile',
        event: 'User assumed high risk.',
        reason: 'Because',
        user_id: user.id,
        username: user.username
      )
      expect { call_method }.to change { user.custom_attributes.count }.by(1)

      record = user.custom_attributes.last
      expect(record.key).to eq described_class::ASSUMED_HIGH_RISK_ATTR_KEY
      expect(record.value).to eq 'Because'
    end
  end

  describe '#assumed_high_risk?' do
    subject(:result) { risk_profile.assumed_high_risk? }

    it { is_expected.to eq false }

    context 'when user has a "assumed_high_risk_reason" custom attribute' do
      before do
        create(:user_custom_attribute, :assumed_high_risk_reason, user: user)
      end

      it { is_expected.to eq true }
    end
  end

  def add_user_risk_band(value)
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: value, user_id: user.id)
  end

  describe('#medium_risk?') do
    subject { risk_profile.medium_risk? }

    where(:arkose_risk_band, :result) do
      nil           | false
      'High'        | false
      'Medium'      | true
      'Low'         | false
      'Unavailable' | false
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
      end

      it { is_expected.to eq result }
    end
  end

  describe('#high_risk?') do
    subject { risk_profile.high_risk? }

    where(:arkose_risk_band, :result) do
      nil           | false
      'High'        | true
      'Medium'      | false
      'Low'         | false
      'Unavailable' | false
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
      end

      it { is_expected.to eq result }
    end
  end

  describe('#arkose_verified?') do
    subject { risk_profile.arkose_verified? }

    where(:arkose_risk_band, :assumed_low_risk, :result) do
      nil           | false | false
      nil           | true  | true
      'High'        | false | true
      'Medium'      | false | true
      'Low'         | false | true
      'Unavailable' | false | true
    end

    with_them do
      before do
        add_user_risk_band(arkose_risk_band) if arkose_risk_band.present?
        user.assume_low_risk!(reason: 'Because') if assumed_low_risk
      end

      it { is_expected.to eq result }
    end
  end
end
