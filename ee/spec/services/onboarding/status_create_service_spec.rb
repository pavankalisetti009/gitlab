# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusCreateService, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user, reload: true) { create(:user) }

    let(:current_user) { user }
    let(:step_url) { 'foobar' }
    let(:params) { {} }
    let(:session) { {} }
    let(:onboarding_status) do
      {
        step_url: step_url,
        initial_registration_type: 'free',
        registration_type: 'free'
      }
    end

    subject(:execute) { described_class.new(params, session, current_user, step_url).execute }

    context 'when onboarding is enabled' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when update is successful' do
        let_it_be(:user_with_members, reload: true) { create(:group_member).user }
        let(:subscription_return) { { 'user_return_to' => ::Gitlab::Routing.url_helpers.new_subscriptions_path } }
        let(:no_sub_return) { { 'user_return_to' => 'some/path' } }

        let(:trial_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'trial',
            registration_type: 'trial'
          }
        end

        let(:invite_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'invite',
            registration_type: 'invite'
          }
        end

        let(:subscription_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'subscription',
            registration_type: 'subscription'
          }
        end

        let(:free_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'free',
            registration_type: 'free'
          }
        end

        where(:params, :session, :current_user, :expected_onboarding_status) do
          { trial: 'true' }  | {}                        | ref(:user_with_members) | ref(:trial_registration)
          { trial: 'true' }  | {}                        | ref(:user)              | ref(:trial_registration)
          { trial: 'false' } | {}                        | ref(:user)              | ref(:free_registration)
          { trial: '' }      | {}                        | ref(:user)              | ref(:free_registration)
          {}                 | {}                        | ref(:user)              | ref(:free_registration)
          {}                 | ref(:subscription_return) | ref(:user)              | ref(:subscription_registration)
          {}                 | ref(:subscription_return) | ref(:user_with_members) | ref(:invite_registration)
          {}                 | {}                        | ref(:user_with_members) | ref(:invite_registration)
          {}                 | {}                        | ref(:user)              | ref(:free_registration)
          {}                 | ref(:no_sub_return)       | ref(:user)              | ref(:free_registration)
        end

        with_them do
          it 'updates onboarding_status_step_url' do
            expect(execute[:user].onboarding_status.symbolize_keys).to eq(expected_onboarding_status)
            expect(execute[:user]).to be_onboarding_in_progress
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_success
          end
        end

        context 'when there is already value in the onboarding_status' do
          before do
            user.update!(onboarding_status_email_opt_in: true)
          end

          it 'merges new data into onboarding_status and does not delete it' do
            expect(execute[:user]).to be_onboarding_in_progress
            expect(execute[:user].onboarding_status.symbolize_keys).to eq(onboarding_status.merge(email_opt_in: true))
          end
        end
      end

      context 'when update is not successful due to systemic failure' do
        before do
          allow(current_user).to receive(:update).and_return(false)
        end

        it 'does not update the onboarding_status_step_url' do
          expect(execute[:user]).not_to be_onboarding_in_progress
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_error
          expect(execute[:user].onboarding_status).to eq({})
        end
      end
    end

    context 'when onboarding is not enabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect(execute[:user]).not_to be_onboarding_in_progress
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_error
        expect(execute[:user].onboarding_status).to eq({})
      end
    end
  end
end
