# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::TrialsController, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  describe 'GET new' do
    subject(:get_new) do
      get '/-/trials/new'
      response
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        expect(get_new).to redirect_to_sign_in
      end
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      context 'when automatic_self_managed_trial_activation feature is enabled' do
        context 'when not on GitLab.com' do
          it 'renders the trial form' do
            expect(get_new).to have_gitlab_http_status(:ok)
            expect(response.body).to include(_('Start your free Ultimate trial!'))
          end
        end
      end

      context 'when automatic_self_managed_trial_activation feature is disabled' do
        before do
          stub_feature_flags(automatic_self_managed_trial_activation: false)
        end

        it 'returns 404' do
          expect(get_new).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST create' do
    let(:trial_params) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email_address: 'john@example.com',
        company_name: 'ACME Corp',
        country: 'US',
        state: 'CA',
        consent_to_marketing: '1'
      }
    end

    subject(:post_create) do
      post '/-/trials', params: trial_params
      response
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        expect(post_create).to redirect_to_sign_in
      end
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      context 'when automatic_self_managed_trial_activation feature is enabled' do
        context 'when not on GitLab.com' do
          context 'when trial submission succeeds' do
            before do
              allow_next_instance_of(GitlabSubscriptions::SelfManaged::CreateTrialService) do |service|
                allow(service).to receive(:execute).and_return(ServiceResponse.success)
              end
            end

            it 'redirects to admin subscription path' do
              expect(post_create).to redirect_to(admin_subscription_path)
            end
          end

          context 'when trial submission fails' do
            before do
              allow_next_instance_of(GitlabSubscriptions::SelfManaged::CreateTrialService) do |service|
                allow(service).to receive(:execute).and_return(
                  ServiceResponse.error(message: 'Trial creation failed')
                )
              end
            end

            it 'renders the resubmit component' do
              expect(post_create).to have_gitlab_http_status(:ok)
              expect(response.body).to include(_('Trial registration unsuccessful'))
            end

            it 'displays the error message' do
              post_create
              expect(response.body).to include('Trial creation failed')
            end
          end
        end

        context 'when on GitLab.com', :saas_subscriptions_trials do
          it 'returns 404' do
            expect(post_create).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when automatic_self_managed_trial_activation feature is disabled' do
        before do
          stub_feature_flags(automatic_self_managed_trial_activation: false)
        end

        it 'returns 404' do
          expect(post_create).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
