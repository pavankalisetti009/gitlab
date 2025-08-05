# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::TokenVerificationRequestService, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:finding) do
    create(:vulnerabilities_finding,
      project: project,
      report_type: 'secret_detection',
      raw_metadata: Gitlab::Json.dump(finding_metadata))
  end

  let!(:token_status) { create(:finding_token_status, finding: finding) }

  let(:finding_metadata) do
    {
      'identifiers' => [
        { 'type' => 'gitleaks_rule_id', 'value' => 'gitlab_pat' }
      ],
      'raw_source_code_extract' => 'gtlb_test123abc'
    }
  end

  let(:service) { described_class.new(user, finding) }
  let(:sdrs_url) { 'https://sdrs.example.com' }
  let(:jwt_token) { 'valid.jwt.token' }

  before do
    stub_licensed_features(secret_detection: true)
    stub_application_setting(
      sdrs_enabled: true,
      sdrs_url: sdrs_url,
      sdrs_jwt_signing_key: OpenSSL::PKey::RSA.generate(2048).to_pem
    )

    allow(Ability).to receive(:allowed?).with(user, :read_vulnerability, project).and_return(true)
    allow(::Authz::SdrsAuthenticationService)
      .to receive(:generate_token).and_return(jwt_token)
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    context 'when feature is disabled' do
      before do
        stub_feature_flags(secret_detection_sdrs_token_verification_flow: false)
      end

      it 'returns error' do
        result = execute_service
        expect(result).to be_error
        expect(result.message).to eq('Feature is disabled')
      end
    end

    context 'when SDRS is not configured' do
      before do
        stub_application_setting(sdrs_enabled: false)
      end

      it 'returns error' do
        result = execute_service
        expect(result).to be_error
        expect(result.message).to eq('SDRS not configured')
      end
    end

    context 'when finding is invalid' do
      context 'when token_value is missing' do
        let(:finding_metadata) do
          {
            'identifiers' => [
              { 'type' => 'gitleaks_rule_id', 'value' => 'gitlab_pat' }
            ]
          }
        end

        before do
          allow(finding).to receive(:token_value).and_return(nil)
        end

        it 'returns error' do
          result = execute_service
          expect(result).to be_error
          expect(result.message).to eq('Invalid finding')
        end
      end

      context 'when token_type is missing' do
        let(:finding_metadata) { { 'raw_source_code_extract' => 'gtlb_test123abc' } }

        it 'returns error' do
          result = execute_service
          expect(result).to be_error
          expect(result.message).to eq('Invalid finding')
        end
      end
    end

    context 'when user unauthorized' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_vulnerability, project).and_return(false)
      end

      it 'returns error' do
        result = execute_service
        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end
    end

    context 'when all validations pass' do
      context 'when JWT generation fails with SigningKeyNotConfigured' do
        before do
          allow(::Authz::SdrsAuthenticationService)
            .to receive(:generate_token)
            .and_raise(::Authz::SdrsAuthenticationService::SigningKeyNotConfigured)
        end

        it 'returns error' do
          result = execute_service
          expect(result).to be_error
          expect(result.message).to eq('Failed to generate JWT')
        end

        it 'updates token status to unknown' do
          expect(token_status).to receive(:update!).with(status: 'unknown')

          execute_service
        end
      end

      context 'when JWT generation fails with StandardError' do
        before do
          allow(::Authz::SdrsAuthenticationService)
            .to receive(:generate_token)
            .and_raise(StandardError)
        end

        it 'returns error' do
          result = execute_service
          expect(result).to be_error
          expect(result.message).to eq('Failed to generate JWT')
        end

        it 'updates token status to unknown' do
          expect(token_status).to receive(:update!).with(status: 'unknown')

          execute_service
        end
      end

      context 'when sending request to SDRS' do
        let(:request_stub) do
          stub_request(:post, "#{sdrs_url}/api/v1/token/verify")
            .with(
              headers: {
                'Authorization' => "Bearer #{jwt_token}",
                'Content-Type' => 'application/json'
              },
              body: hash_including(
                'token_type' => 'gitlab_pat',
                'token_value' => 'gtlb_test123abc',
                'finding_id' => finding.id
              )
            )
        end

        context 'when request is accepted' do
          before do
            request_stub.to_return(status: 202, body: '{}')
          end

          it 'returns success' do
            result = execute_service
            expect(result).to be_success
            expect(result.payload).to include(finding_id: finding.id)
          end

          it 'updates token status to unknown' do
            expect(token_status).to receive(:update!).with(status: 'unknown')
            execute_service
          end
        end

        context 'when request fails' do
          before do
            request_stub.to_return(status: 400, body: '{}')
          end

          it 'returns error' do
            result = execute_service
            expect(result).to be_error
            expect(result.message).to eq('Unexpected SDRS response')
          end

          it 'updates token status to unknown' do
            expect(token_status).to receive(:update!).with(status: 'unknown')

            execute_service
          end
        end

        context 'when network error occurs' do
          before do
            request_stub.to_timeout
          end

          it 'handles network error gracefully' do
            response = execute_service

            expect(response).to be_error
            expect(response.message).to eq('Unexpected error during SDRS request: execution expired')
            expect(response.payload[:error_type]).to eq(Net::OpenTimeout)
          end

          it 'updates token status to unknown' do
            expect(token_status).to receive(:update!).with(status: 'unknown')

            response = execute_service
            expect(response.payload[:error_type]).to eq(Net::OpenTimeout)
          end
        end

        context 'when unexpected error occurs during response handling' do
          before do
            request_stub.to_return(status: 202, body: { status: 'pending' }.to_json)

            allow(service).to receive(:handle_sdrs_response).and_raise(StandardError.new('Unexpected error'))
          end

          it 'tracks the error and returns error response' do
            expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
              .with(
                instance_of(StandardError),
                hash_including(
                  finding_id: finding.id,
                  user_id: user.id,
                  project_id: project.id,
                  token_type: 'gitlab_pat'
                )
              )

            response = execute_service

            expect(response).to be_error
            expect(response.message).to eq('Unexpected error')
            expect(response.payload[:error_type]).to eq(:internal_error)
          end

          it 'updates token status to unknown' do
            expect(token_status).to receive(:update!).with(status: 'unknown')

            expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

            execute_service
          end
        end
      end
    end

    describe 'token type detection' do
      context 'when token_type is in metadata' do
        it 'uses token_type from metadata' do
          stub_request(:post, "#{sdrs_url}/api/v1/token/verify")
            .with(body: hash_including('token_type' => 'gitlab_pat'))
            .to_return(status: 202)

          execute_service

          expect(WebMock).to have_requested(:post, "#{sdrs_url}/api/v1/token/verify")
            .with(body: hash_including('token_type' => 'gitlab_pat'))
        end
      end

      context 'when token_type is not in metadata' do
        let(:finding_metadata) { { 'raw_source_code_extract' => 'gtlb_test123abc' } }

        before do
          allow(finding).to receive(:primary_identifier).and_return(
            build_stubbed(:vulnerabilities_identifier, external_id: 'gitlab_pat')
          )
        end

        it 'returns error due to missing token type' do
          result = execute_service
          expect(result).to be_error
          expect(result.message).to eq('Invalid finding')
        end
      end
    end
  end
end
