# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Users, :aggregate_failures, :api, feature_category: :subscription_management do
  include GitlabSubscriptions::InternalApiHelpers

  describe 'GET /internal/gitlab_subscriptions/users/:id' do
    let_it_be(:user) { create(:user) }

    def users_path(user_id)
      internal_api("users/#{user_id}")
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get users_path(user.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the user exists' do
        it 'returns success' do
          get users_path(user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response["id"]).to eq(user.id)
          expect(json_response.keys).to eq(%w[id username name web_url])
        end
      end

      context 'when user does not exists' do
        it 'returns not found' do
          get users_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq("404 User Not Found")
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      def users_path(user_id)
        "/internal/gitlab_subscriptions/users/#{user_id}"
      end

      context 'when authenticated as user' do
        it 'returns authentication error' do
          get api(users_path(user.id), create(:user))

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as admin' do
        let_it_be(:admin) { create(:admin) }

        it 'returns success' do
          get api(users_path(user.id), admin, admin_mode: true)

          expected_attributes = %w[id username name web_url]

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response["id"]).to eq(user.id)
          expect(json_response.keys).to eq(expected_attributes)
        end

        context 'when user does not exists' do
          it 'returns not found' do
            get api(users_path(non_existing_record_id), admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq("404 User Not Found")
          end
        end
      end
    end
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:namespace_id/user_permissions/:user_id' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:user) { create(:user) }

    def user_permissions_path(namespace_id, user_id)
      internal_api("namespaces/#{namespace_id}/user_permissions/#{user_id}")
    end

    context 'when unauthenticated' do
      it 'returns an authentication error' do
        get user_permissions_path(namespace.id, user.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the user can manage the namespace billing' do
        it 'returns true for edit_billing' do
          namespace.add_owner(user)

          get user_permissions_path(namespace.id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['edit_billing']).to be true
        end
      end

      context 'when the user cannot manage the namespace billing' do
        it 'returns false for edit_billing' do
          get user_permissions_path(namespace.id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['edit_billing']).to be false
        end
      end

      context 'when the namespace does not exist' do
        it 'returns a not found response' do
          get user_permissions_path(non_existing_record_id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the user does not exist' do
        it 'returns a not found response' do
          get user_permissions_path(namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      def user_permissions_path(namespace_id, user_id)
        "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/user_permissions/#{user_id}"
      end

      context 'when authenticated as a non-admin user' do
        it 'returns an authentication error' do
          non_admin = create(:user)

          get api(user_permissions_path(namespace.id, user.id), non_admin)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an admin' do
        let_it_be(:admin) { create(:admin) }

        context 'when the user can manage the namespace billing' do
          it 'returns true for edit_billing' do
            namespace.add_owner(user)

            get api(user_permissions_path(namespace.id, user.id), admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['edit_billing']).to be true
          end
        end

        context 'when the user cannot manage the namespace billing' do
          it 'returns false for edit_billing' do
            get api(user_permissions_path(namespace.id, user.id), admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['edit_billing']).to be false
          end
        end

        context 'when the namespace does not exist' do
          it 'returns a not found response' do
            get api(user_permissions_path(non_existing_record_id, user.id), admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the user does not exist' do
          it 'returns a not found response' do
            get api(user_permissions_path(namespace.id, non_existing_record_id), admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
