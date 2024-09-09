# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::AddOnPurchases, :aggregate_failures, :api, feature_category: :"add-on_provisioning" do
  include GitlabSubscriptions::InternalApiHelpers

  describe 'POST /internal/gitlab_subscriptions/namespaces/:id/subscription_add_on_purchases' do
    let_it_be(:namespace) { create(:group, :with_organization) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }

    let(:add_on_purchases_path) { "namespaces/#{namespace_id}/subscription_add_on_purchases" }
    let(:internal_api_path) { internal_api(add_on_purchases_path) }

    let(:started_on) { Date.current.to_s }
    let(:expires_on) { 1.year.from_now.to_date.to_s }
    let(:namespace_id) { namespace.id }
    let(:purchase_xid) { "A-12345" }
    let(:quantity) { 10 }
    let(:trial) { true }

    let(:params) do
      {
        add_on_purchases: {
          duo_pro: [
            add_on_product
          ]
        }
      }
    end

    let(:add_on_product) do
      {
        started_on: started_on,
        expires_on: expires_on,
        purchase_xid: purchase_xid,
        quantity: quantity,
        trial: trial
      }
    end

    shared_examples 'bulk add-on purchase provision service endpoint' do
      context 'when the namespace cannot be found' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it 'creates a new add-on purchase', :freeze_time do
        expect { result }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(result).to have_gitlab_http_status(:success)
        expect(json_response.first).to eq(
          'namespace_id' => namespace_id,
          'namespace_name' => namespace.name,
          'add_on' => add_on.name.titleize,
          'started_on' => add_on_product[:started_on],
          'expires_on' => add_on_product[:expires_on],
          'purchase_xid' => add_on_product[:purchase_xid],
          'quantity' => add_on_product[:quantity],
          'trial' => add_on_product[:trial]
        )
      end

      context 'when the add-on purchase cannot be saved' do
        let(:quantity) { 0 }

        it 'returns active record errors' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:bad_request)
          expect(result.body).to include('"quantity":["must be greater than or equal to 1"]')
        end
      end

      context 'when the add-on purchase already exists' do
        before do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            quantity: 5,
            purchase_xid: 'A-S000010',
            trial: false
          )
        end

        it 'updates existing add-on purchase' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:success)
          expect(json_response.first).to eq(
            'namespace_id' => namespace_id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'started_on' => add_on_product[:started_on],
            'expires_on' => add_on_product[:expires_on],
            'purchase_xid' => add_on_product[:purchase_xid],
            'quantity' => add_on_product[:quantity],
            'trial' => add_on_product[:trial]
          )
        end
      end

      context 'when parameters miss information' do
        let_it_be(:error) { ServiceResponse.error(message: 'Something went wrong') }

        before do
          allow_next_instance_of(GitlabSubscriptions::AddOnPurchases::CreateService) do |instance|
            allow(instance).to receive(:execute).and_return error
          end
        end

        it 'returns bad request response' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:bad_request)
          expect(result.body).to include('Something went wrong')
        end
      end
    end

    subject do
      post internal_api_path
      response
    end

    it { is_expected.to have_gitlab_http_status(:unauthorized) }

    context 'when authenticated as the subscription portal' do
      subject(:result) do
        post internal_api_path, headers: internal_api_headers, params: params
        response
      end

      before do
        stub_internal_api_authentication
      end

      it_behaves_like 'bulk add-on purchase provision service endpoint'
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      subject(:result) do
        post api_path, params: params
        response
      end

      let(:user) { create(:admin) }
      let(:admin_mode) { true }

      let(:api_path) do
        api(
          "/internal/gitlab_subscriptions/#{add_on_purchases_path}",
          user,
          admin_mode: true
        )
      end

      it_behaves_like 'bulk add-on purchase provision service endpoint'

      context 'with a non-admin user' do
        let(:user) { create(:user) }
        let(:admin_mode) { false }

        it { is_expected.to have_gitlab_http_status(:forbidden) }
      end
    end
  end
end
