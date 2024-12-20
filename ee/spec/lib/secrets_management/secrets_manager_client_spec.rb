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

  describe '#list_secrets', :gitlab_secrets_manager do
    let(:mount_path) { 'some/mount/path' }
    let(:other_mount_path) { 'other/mount/path' }
    let(:secrets_path) { 'secrets' }

    before do
      client.enable_secrets_engine(mount_path, 'kv-v2')
      client.enable_secrets_engine(other_mount_path, 'kv-v2')

      client.create_kv_secret(
        mount_path,
        "#{secrets_path}/DBPASS",
        'somevalue',
        {
          environment: 'staging'
        }
      )

      client.create_kv_secret(
        mount_path,
        "other_secrets/APIKEY",
        'somevalue',
        {
          environment: 'staging'
        }
      )

      client.create_kv_secret(
        other_mount_path,
        "#{secrets_path}/DEPLOYKEY",
        'somevalue',
        {
          environment: 'staging'
        }
      )
    end

    subject(:result) { client.list_secrets(mount_path, secrets_path) }

    it 'returns all matching secrets' do
      expect(result).to contain_exactly(
        a_hash_including(
          "key" => "DBPASS",
          "metadata" => a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      )
    end

    context 'when block is given' do
      it 'yields each entry and returns in the list the returned value of each block' do
        result = client.list_secrets(mount_path, secrets_path) do |data|
          { new_data: data["key"] }
        end

        expect(result).to contain_exactly(new_data: "DBPASS")
      end
    end
  end

  describe '#read_secret_metadata', :gitlab_secrets_manager do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      client.create_kv_secret(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        {
          environment: 'staging'
        }
      )
    end

    subject(:result) { client.read_secret_metadata(mount_path, secret_path) }

    context 'when the secret exists' do
      it 'returns the metadata' do
        expect(result).to match(
          a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it { is_expected.to be_nil }
    end

    context 'when the secret does not exist' do
      let(:secret_path) { 'something/else' }

      it { is_expected.to be_nil }
    end
  end
end
