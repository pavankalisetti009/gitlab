# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ThirdPartyAgents::TokenService, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  let(:ai_gateway_headers) { { 'header' => 'value' } }
  let(:public_headers) do
    {
      'x-gitlab-unit-primitive' => 'ai_gateway_model_provider_proxy',
      'x-gitlab-authentication-type' => 'oidc'
    }
  end

  let(:expected_token) { 'user-access-token' }
  let(:expires_at) { 1.hour.from_now.to_i }
  let(:response_body) { { token: expected_token, expires_at: expires_at }.to_json }
  let(:http_status) { 200 }
  let(:auth_url) { "#{Gitlab::AiGateway.url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}" }

  subject(:token_service) { described_class.new(current_user: user) }

  before do
    allow(Gitlab::AiGateway).to receive(:headers)
      .with(user: user, unit_primitive_name: :ai_gateway_model_provider_proxy, ai_feature_name: :duo_workflow)
      .and_return(ai_gateway_headers)

    allow(Gitlab::AiGateway).to receive(:public_headers)
      .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :ai_gateway_model_provider_proxy)
      .and_return(public_headers)

    allow(Gitlab::AiGateway).to receive(:access_token_url)
      .with(nil)
      .and_return(auth_url)

    stub_request(:post, auth_url)
      .with(
        body: nil,
        headers: ai_gateway_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#direct_access_token' do
    subject(:result) { token_service.direct_access_token }

    it 'returns a successful service response with the token information' do
      expect(result).to be_success
      expect(result.payload).to include(
        headers: public_headers,
        token: expected_token,
        expires_at: expires_at
      )
    end

    it 'logs the token creation' do
      expect(token_service).to receive(:log_info).with(
        message: 'Creating user access token',
        event_name: 'user_token_created',
        ai_component: 'third_party_agents'
      )

      result
    end

    context 'when direct access token creation request fails' do
      let(:http_status) { 401 }
      let(:error_message) { 'No authorization header presented' }
      let(:response_body) { { detail: error_message }.to_json }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 401, ai_gateway_error_detail: error_message }
        )

        result
      end
    end

    context 'when token is not included in response' do
      let(:response_body) { { foo: :bar }.to_json }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token is missing in response')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 200 }
        )

        result
      end
    end

    context 'when returning a server error' do
      let(:http_status) { 503 }

      before do
        stub_request(:post, auth_url)
          .with(
            body: nil,
            headers: ai_gateway_headers
          )
          .to_return(
            status: http_status,
            body: 'Service Unavailable',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 503, ai_gateway_error_detail: 'Service Unavailable' }
        )

        result
      end
    end

    context 'when HTTP request raises an exception' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError.new('Connection error'))
        # Need to handle the exception in the test
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(StandardError), {})
          .and_return(nil)
      end

      it 'returns an error response' do
        expect { result }.to raise_error(StandardError, 'Connection error')
      end
    end
  end

  describe 'creating AI gateway headers' do
    it 'uses the current user for public headers' do
      expect(Gitlab::AiGateway).to receive(:public_headers)
        .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :ai_gateway_model_provider_proxy)
        .and_return(public_headers)

      token_service.direct_access_token
    end

    it 'includes the required headers' do
      expect(token_service.direct_access_token.payload[:headers]).to include(
        'x-gitlab-unit-primitive' => 'ai_gateway_model_provider_proxy',
        'x-gitlab-authentication-type' => 'oidc'
      )
    end
  end
end
