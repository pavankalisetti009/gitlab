# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::ApplyTrialService, feature_category: :acquisition do
  let_it_be(:namespace) { create(:namespace) }

  let(:user) { namespace.owner }
  let(:trial_user_information) { { namespace_id: namespace.id } }
  let(:apply_trial_params) do
    {
      uid: user.id,
      trial_user_information: trial_user_information
    }
  end

  let(:generate_trial_params) do
    {
      uid: user.id,
      trial_user: trial_user_information
    }
  end

  describe '.execute' do
    before do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial).and_return(response)
    end

    subject(:execute) { described_class.execute(**apply_trial_params) }

    context 'when trial is applied successfully' do
      let(:response) { { success: true } }

      it 'returns success: true' do
        expect(execute).to be_success
      end

      it_behaves_like 'records an onboarding progress action', :trial_started
    end
  end

  describe '#execute' do
    subject(:execute) { described_class.new(**apply_trial_params).execute }

    let(:response) { { success: true } }

    context 'when trial is applied successfully', :saas do
      let(:trial_user_information) do
        {
          namespace_id: namespace.id,
          add_on_name: 'duo_enterprise'
        }
      end

      context 'when namespace has a free plan' do
        it 'with expected parameters' do
          expect(Gitlab::SubscriptionPortal::Client)
            .to receive(:generate_trial).with(
              {
                uid: user.id,
                trial_user: trial_user_information.merge(trial_type: :ultimate_with_gitlab_duo_enterprise)
              }
            ).and_return(response)

          expect(execute).to be_success
        end
      end

      context 'when namespace has a premium plan' do
        let_it_be(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }

        it 'with expected parameters' do
          expect(Gitlab::SubscriptionPortal::Client)
            .to receive(:generate_trial).with(
              {
                uid: user.id,
                trial_user: trial_user_information.merge(trial_type: :ultimate_on_premium_with_gitlab_duo_enterprise)
              }
            ).and_return(response)

          expect(execute).to be_success
        end
      end
    end

    context 'when valid to generate a trial' do
      before do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial).and_return(response)
      end

      context 'when trial is applied successfully' do
        it 'returns success: true' do
          expect(execute).to be_success
        end

        it_behaves_like 'records an onboarding progress action', :trial_started

        context 'when namespace has already had a trial', :saas do
          let_it_be(:namespace) do
            create(
              :group_with_plan,
              plan: :free_plan,
              trial: true,
              trial_starts_on: 2.years.ago,
              trial_ends_on: 1.year.ago
            )
          end

          let_it_be(:user) { create(:user, owner_of: namespace) }

          it { is_expected.to be_success }
        end
      end

      context 'with error while applying the trial' do
        let(:response) { { success: false, data: { errors: ['some error'] } } }

        it 'returns success: false with errors and reason' do
          expect(execute).to be_error.and have_attributes(
            message: ['some error'], reason: described_class::GENERIC_TRIAL_ERROR
          )
        end

        it_behaves_like 'does not record an onboarding progress action'
      end
    end

    context 'when not valid to generate a trial' do
      context 'when namespace_id is not in the trial_user_information' do
        let(:trial_user_information) { {} }

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end

      context 'when namespace does not exist' do
        let(:trial_user_information) { { namespace_id: non_existing_record_id } }

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end

      context 'when namespace is already on a trial', :saas do
        let_it_be(:namespace) do
          create(
            :group_with_plan,
            plan: :ultimate_trial_plan,
            trial: true,
            trial_starts_on: 2.years.ago,
            trial_ends_on: 1.year.ago
          )
        end

        let_it_be(:user) { create(:user, owner_of: namespace) }

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end
    end
  end

  describe '#valid_to_generate_trial?' do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }

    subject(:valid_to_generate_trial) { described_class.new(**apply_trial_params).valid_to_generate_trial? }

    context 'when it is valid to generate a trial' do
      it { is_expected.to be true }
    end

    context 'when namespace_id is not in the trial_user_information' do
      let(:trial_user_information) { {} }

      it { is_expected.to be false }
    end

    context 'when namespace does not exist' do
      let(:trial_user_information) { { namespace_id: non_existing_record_id } }

      it { is_expected.to be false }
    end

    context 'when namespace is already on a trial', :saas do
      let_it_be(:namespace) do
        create(
          :group_with_plan,
          plan: :free_plan,
          trial: true,
          trial_starts_on: 2.years.ago,
          trial_ends_on: 1.year.ago
        )
      end

      let_it_be(:user) { create(:user, owner_of: namespace) }

      it { is_expected.to be true }
    end

    context 'when eligible with add_on concerns' do
      before do
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: namespace)
      end

      it { is_expected.to be true }
    end

    context 'when ineligible due to add_on concerns' do
      before do
        create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: duo_pro_add_on, namespace: namespace)
      end

      it { is_expected.to be false }
    end

    context 'with valid plans', :saas do
      where(plan: ::Plan::PLANS_ELIGIBLE_FOR_TRIAL)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }
        let(:user) { create(:user, owner_of: namespace) }

        it { is_expected.to be true }
      end
    end

    context 'with an invalid plan', :saas do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:user) { create(:user, owner_of: namespace) }

      it { is_expected.to be false }
    end
  end
end
