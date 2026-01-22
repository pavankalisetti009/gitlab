# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::TrialsController, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  describe 'GET new' do
    subject(:get_new) do
      get '/-/self_managed/trials/new'
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

        context 'when on GitLab.com', :saas_subscriptions_trials do
          it 'returns 404' do
            expect(get_new).to have_gitlab_http_status(:not_found)
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
end
