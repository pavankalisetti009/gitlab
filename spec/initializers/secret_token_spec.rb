# frozen_string_literal: true

require 'spec_helper'
require_relative '../../config/initializers/01_secret_token'

RSpec.describe 'create_tokens' do
  include StubENV

  let(:allowed_keys) do
    %w[
      secret_key_base
      db_key_base
      otp_key_base
      openid_connect_signing_key
    ]
  end

  let(:hex_key) { /\h{128}/ }
  let(:rsa_key) { /\A-----BEGIN RSA PRIVATE KEY-----\n.+\n-----END RSA PRIVATE KEY-----\n\Z/m }

  around do |example|
    original_credentials = Rails.application.credentials
    # ensure we clear any existing `encrypted_settings_key_base` credential
    allowed_keys.each do |key|
      Rails.application.credentials.public_send(:"#{key}=", nil)
    end
    example.run
    Rails.application.credentials = original_credentials
  end

  before do
    allow(Rails).to receive_message_chain(:root, :join) { |string| string }
    allow(File).to receive(:write).and_call_original
    allow(File).to receive(:write).with('config/secrets.yml')
  end

  describe 'ensure acknowledged secrets in any installations' do
    let(:acknowledged_secrets) do
      %w[secret_key_base otp_key_base db_key_base openid_connect_signing_key encrypted_settings_key_base
        rotated_encrypted_settings_key_base]
    end

    it 'does not allow to add a new secret without a proper handling' do
      create_tokens

      secrets_hash = YAML.load_file(Rails.root.join('config/secrets.yml'))

      secrets_hash.each do |environment, secrets|
        new_secrets = secrets.keys - acknowledged_secrets

        expect(new_secrets).to be_empty,
          <<~EOS
           CAUTION:
           It looks like you have just added new secret(s) #{new_secrets.inspect} to the secrets.yml.
           Please read the development guide for GitLab secrets at doc/development/application_secrets.md before you proceed this change.
           If you're absolutely sure that the change is safe, please add the new secrets to the 'acknowledged_secrets' in order to silence this warning.
          EOS
      end
    end
  end

  context 'when none of the secrets exist' do
    before do
      # ensure we clear any existing `encrypted_settings_key_base` credential
      allowed_keys.each do |key|
        Rails.application.credentials.public_send(:"#{key}=", nil)
      end

      allow(self).to receive(:load_secrets_from_file).and_return({})
      stub_env('SECRET_KEY_BASE', nil)
    end

    it 'generates different hashes for secret_key_base, otp_key_base, and db_key_base' do
      create_tokens

      keys = Rails.application.credentials.values_at(:secret_key_base, :otp_key_base, :db_key_base)

      expect(keys.uniq).to eq(keys)
      expect(keys).to all(match(hex_key))
    end

    it 'generates an RSA key for openid_connect_signing_key' do
      create_tokens

      keys = Rails.application.credentials.values_at(:openid_connect_signing_key)

      expect(keys.uniq).to eq(keys)
      expect(keys).to all(match(rsa_key))
    end

    it 'warns about the secrets to add to secrets.yml' do
      allowed_keys.each do |key|
        expect(self).to receive(:warn_missing_secret).with(key)
      end

      create_tokens
    end

    it 'writes the secrets to secrets.yml' do
      expect(File).to receive(:write).with('config/secrets.yml', any_args) do |_filename, contents, _options|
        new_secrets = YAML.safe_load(contents)['test']

        allowed_keys.each do |key|
          expect(new_secrets[key]).to eq(Rails.application.credentials.values_at(key.to_sym).first)
        end
        expect(new_secrets['encrypted_settings_key_base']).to be_nil # encrypted_settings_key_base is optional
      end

      create_tokens
    end

    context 'when GITLAB_GENERATE_ENCRYPTED_SETTINGS_KEY_BASE is set' do
      let(:allowed_keys) do
        super() + ['encrypted_settings_key_base']
      end

      before do
        stub_env('GITLAB_GENERATE_ENCRYPTED_SETTINGS_KEY_BASE', '1')
        allow(self).to receive(:warn_missing_secret)
      end

      it 'writes the encrypted_settings_key_base secret' do
        expect(self).to receive(:warn_missing_secret).with('encrypted_settings_key_base')
        expect(File).to receive(:write).with('config/secrets.yml', any_args) do |_filename, contents, _options|
          new_secrets = YAML.safe_load(contents)['test']

          expect(new_secrets['encrypted_settings_key_base']).to eq(Rails.application.credentials.encrypted_settings_key_base)
        end

        create_tokens
      end
    end
  end

  shared_examples 'credentials are properly set' do
    it 'sets Rails.application.credentials' do
      create_tokens

      expect(Rails.application.credentials.values_at(*allowed_keys.map(&:to_sym))).to eq(allowed_keys)
    end

    it 'does not issue warnings' do
      expect(self).not_to receive(:warn_missing_secret)

      create_tokens
    end

    it 'does not update secrets.yml' do
      expect(File).not_to receive(:write)

      create_tokens
    end
  end

  context 'when secrets exist in secrets.yml' do
    let(:credentials) do
      Hash[allowed_keys.zip(allowed_keys)]
    end

    before do
      # ensure we clear any existing `encrypted_settings_key_base` credential
      allowed_keys.each do |key|
        Rails.application.credentials.public_send(:"#{key}=", nil)
      end

      allow(self).to receive(:load_secrets_from_file).and_return({
        'test' => credentials
      })
    end

    it_behaves_like 'credentials are properly set'

    context 'when secret_key_base also exist in the environment variable' do
      before do
        stub_env('SECRET_KEY_BASE', 'env_key')
      end

      it 'sets Rails.application.credentials.secret_key_base from the environment variable' do
        create_tokens

        expect(Rails.application.credentials.secret_key_base).to eq('env_key')
      end
    end
  end

  context 'when secrets exist in Rails.application.credentials' do
    before do
      allowed_keys.each do |key|
        Rails.application.credentials.public_send(:"#{key}=", key)
      end
    end

    it_behaves_like 'credentials are properly set'

    context 'when secret_key_base also exist in the environment variable' do
      before do
        stub_env('SECRET_KEY_BASE', 'env_key')
      end

      it 'sets Rails.application.credentials.secret_key_base from the environment variable' do
        create_tokens

        expect(Rails.application.credentials.secret_key_base).to eq('env_key')
      end
    end
  end

  context 'some secrets miss, some are in env, some are in Rails.application.credentials, and some are in secrets.yml' do
    before do
      stub_env('SECRET_KEY_BASE', 'env_key')

      Rails.application.credentials.db_key_base = 'db_key_base'

      allow(self).to receive(:load_secrets_from_file).and_return({
        'test' => { 'otp_key_base' => 'otp_key_base' }
      })
    end

    it 'sets Rails.application.credentials properly, issue a warning and writes config.secrets.yml' do
      expect(self).to receive(:warn_missing_secret).with('openid_connect_signing_key')
      expect(File).to receive(:write).with('config/secrets.yml', any_args) do |_filename, contents, _options|
        new_secrets = YAML.safe_load(contents)['test']

        expect(new_secrets['otp_key_base']).to eq('otp_key_base')
        expect(new_secrets['openid_connect_signing_key']).to match(rsa_key)
      end

      create_tokens

      expect(Rails.application.credentials.secret_key_base).to eq('env_key')
      expect(Rails.application.credentials.db_key_base).to eq('db_key_base')
      expect(Rails.application.credentials.otp_key_base).to eq('otp_key_base')
    end
  end
end
