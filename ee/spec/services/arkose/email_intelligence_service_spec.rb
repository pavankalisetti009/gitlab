# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::EmailIntelligenceService, feature_category: :instance_resiliency do
  let(:session_token) { '22612c147bb418c8.2570749403' }
  let(:email) { 'example.user@gmail.com' }
  let(:service) { described_class.new(email: email) }
  let(:verify_api_url) { "https://verify-api.arkoselabs.com/api/v4/verify/" }
  let(:arkose_session_url) { "https://client-api.arkoselabs.com/fc/gt2/public_key/#{arkose_labs_public_api_key}" }
  let(:arkose_labs_public_api_key) { 'foo' }
  let(:arkose_session_response) { { token: session_token } }
  let_it_be(:arkose_verify_response) do
    Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/email_intelligence_response.json')))
  end

  let(:status_code) { 200 }

  subject(:service_response) { service.execute }

  before do
    stub_application_setting(arkose_labs_public_api_key: arkose_labs_public_api_key)

    stub_request(:post, verify_api_url)
      .with(
        body: /.*/,
        headers: {
          'Accept' => '*/*'
        }
      ).to_return(
        status: status_code,
        body: arkose_verify_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:post, arkose_session_url)
      .with(
        body: /.*/,
        headers: {
          'Accept' => '*/*'
        }
      ).to_return(
        status: status_code,
        body: arkose_session_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#execute' do
    it 'returns a success response' do
      expect(service_response).to be_success
    end

    it 'returns the expected email intelligence data', :aggregate_failures do
      response = service_response

      expect(response.payload.detumbled_email_address).to eq 'exampleuser@gmail.com'
      expect(response.payload.email_risk_score).to eq 0
    end

    it 'logs the response' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'Arkose email intelligence succeeded',
        email: email,
        'arkose.email_intelligence': arkose_verify_response['email_intelligence']
      )

      service_response
    end

    shared_examples 'a service error' do
      it 'returns an error response' do
        expect(service_response).to be_error
      end

      it 'returns an error message' do
        expect(service_response.message).to eq error_message
      end

      it 'logs the error' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          message: 'Arkose email intelligence failed',
          reason: error_message,
          session_token: session_token,
          email: email
        )

        subject
      end
    end

    context 'when an error occurs during the Arkose request' do
      let(:error_message) { 'Connection refused - bad connection' }
      let(:session_token) { '' }

      before do
        allow(Gitlab::HTTP).to receive(:perform_request).and_raise(Errno::ECONNREFUSED.new('bad connection'))
      end

      it_behaves_like 'a service error'
    end

    context 'when an Arkose request returns an unexpected status code' do
      let(:status_code) { 401 }
      let(:arkose_session_response) { 'Unauthorized' }
      let(:session_token) { '' }
      let(:error_message) { 'Arkose API call failed with status code: 401, response: "Unauthorized"' }

      it_behaves_like 'a service error'
    end

    context 'when the Arkose session token is not present in the response body' do
      let(:arkose_session_response) { {} }
      let(:session_token) { '' }
      let(:error_message) { 'Failed to retrieve Arkose session token' }

      it_behaves_like 'a service error'
    end

    context 'when there is an error calling the Arkose verify API' do
      let(:error_message) { 'DENIED ACCESS' }
      let(:arkose_verify_response) { { error: error_message } }

      it_behaves_like 'a service error'
    end

    context 'when there is an error in the email intelligence response' do
      let(:error_message) { 'email intelligence not enabled on key' }
      let(:arkose_verify_response) { { email_intelligence: { error: error_message } } }

      it_behaves_like 'a service error'
    end
  end
end
