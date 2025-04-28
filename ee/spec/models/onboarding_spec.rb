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

  describe '.completed_welcome_step?' do
    let(:user) { build(:user) }

    context 'with a user who has never set the value' do
      it 'returns false' do
        expect(described_class.completed_welcome_step?(user)).to be false
      end
    end

    context 'when value has been explicitly set' do
      where(:value_to_set, :expected_result) do
        true  | true
        false | true
      end

      with_them do
        before do
          user.onboarding_status_setup_for_company = value_to_set
        end

        it 'returns true indicating step was completed' do
          expect(described_class.completed_welcome_step?(user)).to be true
        end
      end
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

  describe '.add_on_seat_assignment_iterable_params' do
    let(:namespace) { build(:namespace, id: non_existing_record_id) }

    subject(:params) { described_class.add_on_seat_assignment_iterable_params(user, 'product_interaction', namespace) }

    it 'has the correct params that are stringified' do
      expected_params = {
        'first_name' => user.first_name,
        'last_name' => user.last_name,
        'work_email' => user.email,
        'namespace_id' => namespace.id,
        'product_interaction' => 'product_interaction',
        'existing_plan' => namespace.actual_plan_name,
        'preferred_language' => 'English',
        'opt_in' => user.onboarding_status_email_opt_in
      }

      expect(params).to eq(expected_params)
    end
  end
end
