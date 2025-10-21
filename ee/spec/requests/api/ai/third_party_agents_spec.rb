# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::ThirdPartyAgents, feature_category: :duo_agent_platform do
  include WorkhorseHelpers

  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:unauthorized_user) { build(:user) }
  let_it_be(:api_token) { create(:personal_access_token, scopes: %w[api], user: authorized_user) }
  let_it_be(:ai_features_token) { create(:personal_access_token, scopes: %w[ai_features], user: authorized_user) }
  let_it_be(:unauthorized_token) { create(:personal_access_token, scopes: %w[api], user: unauthorized_user) }
  let_it_be(:current_user) { nil }
  let_it_be(:expires_at) { 1.hour.from_now.to_i }

  let(:headers) { {} }
  let(:token) { 'generated-jwt' }
  let(:service_response) do
    ServiceResponse.success(
      message: "Direct Access Token Generated",
      payload: {
        headers: {
          'x-gitlab-unit-primitive' => 'duo_agent_platform',
          'x-gitlab-authentication-type' => 'oidc'
        },
        token: token,
        expires_at: expires_at
      }
    )
  end

  before do
    stub_application_setting(disabled_direct_code_suggestions: false)
    stub_request(:post, %r{https://cloud.gitlab.com/auth/v1/code/user_access_token})
      .to_return(status: 200, body: { token: 'test-token', expires_at: expires_at }.to_json)
  end

  describe 'POST /ai/third_party_agents/direct_access' do
    subject(:post_api) do
      post api('/ai/third_party_agents/direct_access', current_user), headers: headers
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(agent_platform_claude_code: false)
      end

      let_it_be(:current_user) { authorized_user }

      it 'returns 404' do
        post_api
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user is not logged in' do
      let_it_be(:current_user) { nil }

      it 'returns 401 unauthorized' do
        post_api
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is logged in' do
      let_it_be(:current_user) { authorized_user }

      before do
        allow_next_found_instance_of(User) do |user|
          allow(user).to receive(:allowed_to_use?).with(
            :duo_agent_platform, unit_primitive_name: :ai_gateway_model_provider_proxy
          ).and_return(true)
        end
      end

      context 'when token service succeeds' do
        before do
          allow_next_instance_of(Ai::ThirdPartyAgents::TokenService) do |service|
            allow(service).to receive(:direct_access_token).and_return(service_response)
          end
        end

        it 'returns the token response' do
          post_api

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to eq(service_response.payload.deep_stringify_keys)
        end
      end

      context 'when token service fails' do
        before do
          allow_next_instance_of(Ai::ThirdPartyAgents::TokenService) do |service|
            allow(service).to receive(:direct_access_token).and_return(
              ServiceResponse.error(message: 'Token creation failed')
            )
          end
        end

        it 'returns service unavailable' do
          post_api

          expect(response).to have_gitlab_http_status(:service_unavailable)
          expect(json_response).to eq({ 'message' => 'Token creation failed' })
        end
      end

      context 'when using API token' do
        before do
          allow_next_instance_of(Ai::ThirdPartyAgents::TokenService) do |service|
            allow(service).to receive(:direct_access_token).and_return(service_response)
          end

          headers["Authorization"] = "Bearer #{api_token.token}"
        end

        it 'returns successful response' do
          post_api
          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end
end
