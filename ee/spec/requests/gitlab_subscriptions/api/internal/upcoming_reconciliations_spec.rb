# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::UpcomingReconciliations, :aggregate_failures, :api, feature_category: :subscription_management do
  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    stub_application_setting(check_namespace_plan: true)
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:namespace_id/upcoming_reconciliations' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        put api('/internal/gitlab_subscriptions/namespaces/1/upcoming_reconciliations')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as user' do
      let_it_be(:user) { create(:user) }

      it 'returns authentication error' do
        put api('/internal/gitlab_subscriptions/namespaces/1/upcoming_reconciliations', user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      let_it_be(:default_organization) { create(:organization, :default) }
      let_it_be(:admin) { create(:admin) }
      let_it_be(:namespace) { create(:namespace) }
      let(:namespace_id) { namespace.id }
      let(:path) { "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/upcoming_reconciliations" }

      let(:params) do
        {
          next_reconciliation_date: Date.today + 5.days,
          display_alert_from: Date.today - 2.days
        }
      end

      it_behaves_like 'PUT request permissions for admin mode' do
        let(:params) do
          {
            next_reconciliation_date: Date.today + 5.days,
            display_alert_from: Date.today - 2.days
          }
        end
      end

      subject(:put_upcoming_reconciliations) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'returns success' do
        put_upcoming_reconciliations

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when update service failed' do
        let(:error_message) { 'update_service_error' }

        before do
          allow_next_instance_of(::UpcomingReconciliations::UpdateService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
          end
        end

        it 'returns error' do
          put_upcoming_reconciliations

          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(json_response.dig('message', 'error')).to eq(error_message)
        end
      end

      context 'when not gitlab.com' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns 403 error' do
          put_upcoming_reconciliations

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('403 Forbidden - This API is gitlab.com only!')
        end
      end
    end
  end

  describe 'DELETE /internal/gitlab_subscriptions/namespaces/:namespace_id/upcoming_reconciliations' do
    let_it_be(:namespace) { create(:namespace) }
    let(:path) { "/internal/gitlab_subscriptions/namespaces/#{namespace.id}/upcoming_reconciliations" }

    it_behaves_like 'DELETE request permissions for admin mode' do
      before do
        create(:upcoming_reconciliation, namespace_id: namespace.id)
      end
    end

    context 'when the request is not authenticated' do
      it 'returns authentication error' do
        delete api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as user' do
      it 'returns authentication error' do
        user = create(:user)

        expect { delete api(path, user) }
          .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as an admin' do
      let_it_be(:admin) { create(:admin) }

      context 'when the request is not for .com' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns an error' do
          expect { delete api(path, admin, admin_mode: true) }
            .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(response.body).to include('403 Forbidden - This API is gitlab.com only!')
        end
      end

      context 'when there is an upcoming reconciliation for the namespace' do
        it 'destroys the reconciliation and returns success' do
          create(:upcoming_reconciliation, namespace_id: namespace.id)

          expect { delete api(path, admin, admin_mode: true) }
            .to change { ::GitlabSubscriptions::UpcomingReconciliation.where(namespace_id: namespace.id).count }
            .by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when the namespace_id does not have an upcoming reconciliation' do
        it 'returns a not found error' do
          expect { delete api(path, admin, admin_mode: true) }
            .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
