# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::CodeSuggestionsClient, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }

  let(:unit_primitive) { :complete_code }
  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:ai_gateway_headers) { { 'header' => 'value' } }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:cloud_connector_auth_endpoint_url) do
    "#{Gitlab::AiGateway.cloud_connector_auth_url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}"
  end

  let(:self_hosted_auth_endpoint_url) { "#{Gitlab::AiGateway.self_hosted_url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}" }

  let(:expected_ai_feature) { :code_suggestions }

  let(:body) { { choices: [{ text: "puts \"Hello World!\"\nend", index: 0, finish_reason: "length" }] } }
  let(:code) { 200 }
  let(:cloud_connector_code_completions_url) { 'https://cloud-connector.gitlab.com/v2/code/completions' }

  before do
    allow(user).to receive(:allowed_to_use).and_return(auth_response)
    allow(Gitlab::AiGateway).to receive_messages(
      self_hosted_url: 'http://local-aigw:5052',
      cloud_connector_url: 'https://cloud-connector.gitlab.com',
      cloud_connector_auth_url: 'https://cloud-connector.gitlab.com/auth'
    )
    allow(Gitlab::AiGateway).to receive(:headers).with(
      user: user, unit_primitive_name: unit_primitive, ai_feature_name: expected_ai_feature
    ).and_return(ai_gateway_headers)
  end

  shared_examples "error response" do |message|
    it "returns an error" do
      expect(result).to eq(message)
    end
  end

  shared_context 'with completions' do
    context 'when response does not contain a valid choice' do
      let(:body) { { choices: [] } }

      it_behaves_like 'error response', "Response doesn't contain a completion"
    end
  end

  shared_context 'with tests requests' do
    before do
      [
        cloud_connector_code_completions_url,
        /#{Gitlab::AiGateway.url}/
      ].each do |url|
        stub_request(:post, url).to_return(
          status: code,
          body: body.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end
    end

    it 'returns nil if there is no error' do
      expect(result).to be_nil
    end

    context 'when request raises an error' do
      before do
        [
          cloud_connector_code_completions_url,
          /#{Gitlab::AiGateway.url}/
        ].each do |url|
          stub_request(:post, url).to_raise(StandardError.new('an error'))
        end
      end

      it 'tracks an exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

        result
      end

      it_behaves_like 'error response', 'an error'
    end
  end

  describe "#test_completion" do
    subject(:result) { described_class.new(user).test_completion }

    include_examples 'with tests requests' do
      include_examples 'with completions'
    end

    context 'when response code is not 200' do
      let(:code) { 401 }
      let(:body) { 'an error' }

      it_behaves_like 'error response', 'AI Gateway returned code 401: "an error"'
    end
  end

  describe '#test_model_connection', :with_cloud_connector do
    let(:self_hosted_model) { create(:ai_self_hosted_model) }
    let(:endpoint) { "#{Gitlab::AiGateway.url}/v1/prompts/model_configuration%2Fcheck" }

    subject(:result) { described_class.new(user).test_model_connection(self_hosted_model) }

    context 'when there is no self-hosted model provided' do
      let(:self_hosted_model) { nil }

      it_behaves_like 'error response', "No self-hosted model was provided"
    end

    context 'when the AI Gateway responded with a 421 Misdirected Request' do
      # This means that the model server returned an error
      before do
        stub_request(:post, endpoint)
          .to_return(
            status: 421,
            body: { detail: "401: Unauthorized" }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it_behaves_like 'error response', "The self-hosted model server returned code 401: Unauthorized"
    end

    context 'when response code is not 200 and response.body is valid json' do
      before do
        stub_request(:post, endpoint)
          .to_return(
            status: 401,
            body: { detail: [{ msg: "a specific error" }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it_behaves_like 'error response', "AI Gateway returned code 401: a specific error"
    end

    context 'when response code is not 200 and response.body is a string' do
      before do
        stub_request(:post, endpoint)
          .to_return(
            status: 404,
            body: "a string",
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it_behaves_like 'error response', "AI Gateway returned code 404: " \
        "Unknown error. Make sure your self-hosted model is running and that " \
        "your AI Gateway URL is configured correctly."
    end

    include_examples 'with tests requests'
  end

  describe '#direct_access_token', :with_cloud_connector do
    include StubRequests

    let(:expected_token) { 'user token' }
    let(:expires_at) { 1.hour.from_now.to_i }
    let(:expected_response) { { token: expected_token, expires_at: expires_at } }
    let(:response_body) { expected_response.to_json }
    let(:http_status) { 200 }
    let(:client) { described_class.new(user) }

    let(:auth_url) { self_hosted_auth_endpoint_url }

    subject(:result) { client.direct_access_token }

    before do
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

    it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }

    context 'when code_completions is vendored' do
      before do
        create(:ai_feature_setting, :code_completions, provider: :vendored)
      end

      let(:auth_url) { cloud_connector_auth_endpoint_url }

      it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }
    end

    context 'when code_completions is self-hosted' do
      let(:expected_ai_feature) { :code_suggestions }

      before do
        create(:ai_feature_setting, :code_completions, provider: :self_hosted)
      end

      it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }
    end

    context 'when direct access token creation request fails' do
      let(:http_status) { 401 }
      let(:error_message) { 'No authorization header presented' }
      let(:response_body) { { detail: error_message }.to_json }

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception, _extra|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token creation failed'
          },
          { ai_gateway_response_code: 401, ai_gateway_error_detail: error_message }
        )

        result
      end
    end

    context 'when token is not included in response' do
      let(:response_body) { { foo: :bar }.to_json }

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token is missing in response'
          },
          { ai_gateway_response_code: 200 }
        )

        result
      end
    end

    context 'when returning a string error' do
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

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token creation failed'
          },
          { ai_gateway_response_code: 503, ai_gateway_error_detail: 'Service Unavailable' }
        )

        result
      end
    end
  end
end
