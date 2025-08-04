# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsController, feature_category: :subscription_management do
  let_it_be(:user) { create(:user) }

  describe 'GET #new' do
    context 'when the request is unauthenticated' do
      subject(:get_new) { get :new, params: { plan_id: 'premium-plan-id' } }

      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_registration_path }

      it 'stores the subscription path to redirect to after sign up' do
        get_new

        expect(controller.stored_location_for(:user)).to eq(new_subscriptions_path(plan_id: 'premium-plan-id'))
      end
    end

    context 'when the user is authenticated' do
      before do
        sign_in(user)
      end

      let_it_be(:owned_group) { create(:group) }

      before_all do
        owned_group.add_owner(user)
      end

      context 'when the user has already selected a group' do
        before do
          allow(GitlabSubscriptions)
            .to receive(:find_eligible_namespace)
            .with(user: user, namespace_id: owned_group.id.to_s)
            .and_return(owned_group)
        end

        it 'redirects to customers dot' do
          get :new, params: { plan_id: 'premium-plan-id', namespace_id: owned_group.id }

          expect(response)
            .to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{owned_group.id}&plan_id=premium-plan-id}
        end
      end

      context 'when the user has not selected a group' do
        it 'redirects to the group selection page' do
          get :new, params: { plan_id: 'premium-plan-id' }

          expect(response).to redirect_to %r{/-/subscriptions/groups/new\?plan_id=premium-plan-id}
        end
      end

      context 'when URL has no plan_id param' do
        before do
          get :new
        end

        it { is_expected.to redirect_to promo_pricing_url }
      end
    end
  end

  describe 'GET #buy_minutes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:plan_id) { 'ci_minutes' }

    context 'when the user not authenticated' do
      it 'redirects to the sign in page' do
        get :buy_minutes, params: { selected_group: group.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when the user is authenticated' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'when the add on does not exist' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it 'returns not found' do
          get :buy_minutes, params: { selected_group: group.id }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add on exists' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'ci_minutes' }] })
        end

        context 'when the group does not exist' do
          it 'returns not found' do
            get :buy_minutes, params: { selected_group: non_existing_record_id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is not eligible for CI minutes' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'ci_minutes')
              .and_return(nil)
          end

          it 'returns not found' do
            get :buy_minutes, params: { selected_group: group.id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is eligible for CI minutes' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'ci_minutes')
              .and_return(group)
          end

          it 'redirects to the customers dot purchase flow' do
            get :buy_minutes, params: { selected_group: group.id }

            expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=ci_minutes}
          end
        end
      end
    end
  end

  describe 'GET #buy_storage' do
    let_it_be(:group) { create(:group) }

    context 'when the user not authenticated' do
      it 'redirects to the sign in page' do
        get :buy_storage, params: { selected_group: group.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when the user is authenticated' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'when the add on does not exist' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it 'returns not found' do
          get :buy_storage, params: { selected_group: group.id }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add on exists' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'storage' }] })
        end

        context 'when the group does not exist' do
          it 'returns not found' do
            get :buy_storage, params: { selected_group: non_existing_record_id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is not eligible for storage' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'storage')
              .and_return(nil)
          end

          it 'returns not found' do
            get :buy_storage, params: { selected_group: group.id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is eligible for storage' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'storage')
              .and_return(group)
          end

          it 'redirects to the customers dot purchase flow' do
            get :buy_storage, params: { selected_group: group.id }

            expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=storage}
          end
        end
      end
    end
  end

  describe 'GET #payment_form' do
    subject { get :payment_form, params: { id: 'cc', user_id: 5 } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { signature: 'x', token: 'y' } }

        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:payment_form_params)
          .with('cc', user.id)
          .and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"signature":"x","token":"y"}')
      end
    end
  end

  describe 'GET #validate_payment_method' do
    let(:params) { { id: 'foo' } }

    subject do
      post :validate_payment_method, params: params, as: :json
    end

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:unauthorized) }
    end

    context 'with authorized user' do
      before do
        sign_in(user)

        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:validate_payment_method)
          .with(params[:id], { gitlab_user_id: user.id })
          .and_return({ success: true })
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it { is_expected.to be_successful }
    end
  end
end
