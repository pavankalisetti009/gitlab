# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretsManagerClient, feature_category: :secrets_management do
  let(:client) { described_class.new }

  before do
    Typhoeus::Expectation.clear
  end

  shared_examples_for 'making api request' do
    let(:api_root_url) { "#{OpenbaoClient::Configuration.default.host}/v1" }
    let(:mocked_response) { {} }

    it 'calls the correct OpenBao endpoint' do
      stub_request(:any, %r{#{api_root_url}#{path}})
        .with { |request| expect(Gitlab::Json.parse(request.body)).to include(payload) }
        .to_return_json(body: mocked_response)

      expect { make_request }.not_to raise_error
    end

    context 'when the request results to an API error' do
      it 'raises the error' do
        expect(OpenbaoClient::ApiClient.default).to receive(:call_api) do
          raise OpenbaoClient::ApiError, 'some error message'
        end

        expect { make_request }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end
  end

  describe '.expected_server_version' do
    it 'returns the content of GITLAB_OPENBAO_VERSION file' do
      path = Rails.root.join(described_class::SERVER_VERSION_FILE)
      version = path.read.chomp

      expect(described_class.expected_server_version).to eq(version)
    end
  end

  describe '#enable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }
    let(:engine) { 'kv-v2' }

    subject(:make_request) { client.enable_secrets_engine(mount_path, engine) }

    it_behaves_like 'making api request' do
      let(:path) { "/sys/mounts/#{mount_path}" }

      let(:payload) do
        {
          "type" => "kv-v2"
        }
      end
    end
  end
end
