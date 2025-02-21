# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionProjectSecretsManagerService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:client) { SecretsManagement::SecretsManagerClient.new }

    before do
      rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
      stub_application_setting(ci_jwt_signing_key: rsa_key)
    end

    it 'enables the secret engine for the project and activates the secret manager', :aggregate_failures do
      expect(result).to be_success

      expect(secrets_manager.reload).to be_active

      expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
      expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)
    end

    context 'when the secrets engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines

        client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, described_class::SECRET_ENGINE_TYPE)
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
        expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)
      end
    end

    context 'when the auth engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines

        client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
      end

      it 'still activates the secrets manager and creates the KV mount' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(secrets_manager.ci_secrets_mount_path)
        expect_jwt_auth_engine_to_be_mounted(secrets_manager.ci_auth_mount)

        expect { client.read_jwt_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role) }.not_to raise_error
      end
    end
  end
end
