# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FinishService, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true) }

  describe '#execute' do
    subject(:execute) { described_class.new(user).execute }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'updates onboarding_in_progress to false' do
        expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end

      context 'when update fails' do
        before do
          allow(user).to receive(:update).and_return(false)
        end

        it 'does not update onboarding_in_progress' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(::Onboarding::StepUrlError),
            onboarding_status: user.onboarding_status.to_json,
            user_id: user.id
          )

          expect { execute }.not_to change { user.onboarding_in_progress }
          expect(user).to be_onboarding_in_progress
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_error
        end
      end
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect { execute }.not_to change { user.onboarding_in_progress }
        expect(user).to be_onboarding_in_progress
      end
    end
  end

  describe '#onboarding_attributes' do
    subject { described_class.new(user).onboarding_attributes }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to eq({ onboarding_in_progress: false }) }
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to eq({}) }
    end
  end
end
