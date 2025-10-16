# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::FetchModelDefinitionsService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:endpoint_url) { "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions" }
  let(:cache_key) { described_class::RESPONSE_CACHE_NAME }
  let(:unit_primitive) { :code_suggestions }
  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  let(:initialized_class) { described_class.new(user, model_selection_scope: group) }

  subject(:service) { initialized_class.execute }

  before do
    allow(::Gitlab::AiGateway).to receive(:headers)
      .with(user: user, unit_primitive_name: unit_primitive, ai_feature_name: unit_primitive)
  end

  describe '#duo_features_enabled?' do
    let(:duo_available) { true }

    subject(:method_call) { initialized_class.send(:duo_features_enabled?) }

    before do
      stub_application_setting(duo_features_enabled: duo_available)
    end

    context 'when duo_features_enabled is true' do
      it 'returns true' do
        expect(method_call).to be(true)
      end
    end

    context 'when application setting duo_features_enabled is disabled' do
      let(:duo_available) { false }

      it 'returns false' do
        expect(method_call).to be(false)
      end
    end
  end

  describe '#execute' do
    context 'when duo features is disabled (duo_features_enabled = false)' do
      before do
        stub_application_setting(duo_features_enabled: false)
      end

      it 'returns success ServiceResponse with nil payload' do
        expect(service).to be_success
        expect(service.payload).to be_nil
      end
    end

    context 'when duo features is enabled' do
      before do
        stub_application_setting(duo_features_enabled: true)
      end

      context 'and license is offline' do
        before do
          license = create(:license)
          allow(::License).to receive(:current).and_return(license)
          allow(license).to receive(:offline_cloud_license?).and_return(true)
        end

        it 'returns success ServiceResponse with nil payload' do
          expect(service).to be_success
          expect(service.payload).to be_nil
        end
      end

      context 'when response is cached' do
        let(:cached_data) { model_definitions }

        before do
          allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
          allow(Rails.cache).to receive(:fetch).with(cache_key).and_return(cached_data)
        end

        it 'returns cached response' do
          expect(service).to be_success
          expect(service.payload).to eq(cached_data)
        end

        it 'does not make an HTTP request' do
          expect(Gitlab::HTTP).not_to receive(:get)
          service
        end
      end

      context 'when response is not cached' do
        before do
          allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
        end

        context 'when API call is successful' do
          before do
            stub_request(:get, endpoint_url)
              .to_return(
                status: 200,
                body: model_definitions_response,
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'caches and returns the response' do
            expect(Rails.cache).to receive(:fetch).with(
              cache_key,
              expires_in: described_class::RESPONSE_CACHE_EXPIRATION
            )

            expect(service).to be_success
            expect(service.payload).to include(model_definitions)
          end
        end

        context 'when API call returns error' do
          let(:error_message) { "Received error 401 from AI gateway when fetching model definitions" }

          before do
            stub_request(:get, endpoint_url)
              .to_return(
                status: 401,
                body: "{\"error\":\"No authorization header presented\"}",
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'logs the error and returns error ServiceResponse' do
            expect(initialized_class).to receive(:log_error)

            expect(service).to be_error
            expect(service.message).to eq(error_message)
          end
        end

        context 'when API call raises network error (SocketError)' do
          before do
            allow(Gitlab::HTTP).to receive(:get).and_raise(SocketError.new('Connection failed'))
          end

          it 'handles error gracefully and returns error ServiceResponse' do
            expect(service).to be_error
            expect(service.message).to eq('Failed to fetch model definitions')
          end
        end

        context 'when API call raises timeout error (Net::OpenTimeout)' do
          before do
            allow(Gitlab::HTTP).to receive(:get).and_raise(Net::OpenTimeout.new('Request timeout'))
          end

          it 'handles timeout gracefully and returns error ServiceResponse' do
            expect(service).to be_error
            expect(service.message).to eq('Failed to fetch model definitions')
          end
        end

        context 'when API call raises unexpected StandardError' do
          before do
            allow(Gitlab::HTTP).to receive(:get).and_raise(StandardError.new('Unexpected error'))
          end

          it 'handles unexpected error gracefully and returns error ServiceResponse' do
            expect(service).to be_error
            expect(service.message).to eq('Failed to fetch model definitions')
          end
        end
      end
    end
  end

  describe 'local development behavior with respect to cache' do
    context 'when FETCH_MODEL_SELECTION_DATA_FROM_LOCAL environment variable is set' do
      let(:local_endpoint_url) { 'http://local-gateway.com/v1/models%2Fdefinitions' }

      before do
        stub_application_setting(duo_features_enabled: true)
        allow(::Gitlab::AiGateway).to receive(:url).and_return('http://local-gateway.com')
      end

      %w[1 true True TRUE].each do |truthy_value|
        context "with value set to '#{truthy_value}'" do
          before do
            stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', truthy_value)
            stub_request(:get, local_endpoint_url)
              .to_return(
                status: 200,
                body: model_definitions_response,
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'uses local endpoint and skips cache even when cache exists' do
            allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
            expect(Rails.cache).to receive(:fetch).with(
              cache_key,
              expires_in: described_class::RESPONSE_CACHE_EXPIRATION
            ).and_return(model_definitions)

            expect(Gitlab::HTTP).to receive(:get).with(
              local_endpoint_url,
              hash_including(allow_local_requests: true)
            ).and_call_original

            expect(service).to be_success
          end
        end
      end

      ['0', 'false', 'False', 'FALSE', '', nil].each do |falsy_value|
        context "with value set to '#{falsy_value}'" do
          before do
            stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', falsy_value)
          end

          it 'uses and respects cache' do
            allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
            allow(Rails.cache).to receive(:fetch).with(cache_key).and_return(model_definitions)

            # Should not make HTTP request when cache exists
            expect(Gitlab::HTTP).not_to receive(:get)

            expect(service).to be_success
            expect(service.payload).to eq(model_definitions)
          end
        end
      end
    end
  end

  describe 'endpoint behavior' do
    before do
      stub_application_setting(duo_features_enabled: true)
    end

    context 'when not in local development' do
      before do
        stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', nil)
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
      end

      it 'uses the cloud-connected endpoint URL' do
        stub_request(:get, "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions")
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        expect(service).to be_success
      end
    end

    context 'when in local development' do
      before do
        stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', '1')
        allow(::Gitlab::AiGateway).to receive(:url).and_return('http://local-gateway.com')
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
      end

      it 'uses the local endpoint URL' do
        stub_request(:get, 'http://local-gateway.com/v1/models%2Fdefinitions')
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        expect(service).to be_success
      end
    end
  end
end
