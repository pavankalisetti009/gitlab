# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionProjectSecretsManagerService, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:client) { instance_double(SecretsManagement::SecretsManagerClient) }

    it 'enables the secret engine for the project and activates the secret manager', :aggregate_failures do
      expect_next_instance_of(SecretsManagement::SecretsManagerClient) do |client|
        expect(client).to receive(:enable_secrets_engine).with(secrets_manager.ci_secrets_mount_path, 'kv-v2')
      end

      expect(result).to be_success

      expect(secrets_manager.reload).to be_active
    end

    context 'when the secrets engine has already been enabled' do
      it 'still activates the secrets manager' do
        expect_next_instance_of(SecretsManagement::SecretsManagerClient) do |client|
          expect(client)
            .to receive(:enable_secrets_engine).with(secrets_manager.ci_secrets_mount_path, 'kv-v2')
            .and_raise(
              SecretsManagement::SecretsManagerClient::ApiError,
              %(Response body: {"errors":["path is already in use at #{secrets_manager.ci_secrets_mount_path}"]})
            )
        end

        expect(result).to be_success

        expect(secrets_manager.reload).to be_active
      end
    end
  end
end
