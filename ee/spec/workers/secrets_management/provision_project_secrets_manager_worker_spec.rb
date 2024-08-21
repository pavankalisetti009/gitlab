# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionProjectSecretsManagerWorker, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:project) { create(:project) }

    let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

    it 'executes a service' do
      expect(SecretsManagement::ProjectSecretsManager)
        .to receive(:find_by_id).with(secrets_manager.id).and_return(secrets_manager)

      service = instance_double(SecretsManagement::ProvisionProjectSecretsManagerService)
      expect(SecretsManagement::ProvisionProjectSecretsManagerService)
        .to receive(:new).with(secrets_manager).and_return(service)

      expect(service).to receive(:execute)

      worker.perform(secrets_manager.id)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { secrets_manager.id }
      let(:client_1) { instance_double(SecretsManagement::SecretsManagerClient) }
      let(:client_2) { instance_double(SecretsManagement::SecretsManagerClient) }

      before do
        allow(SecretsManagement::SecretsManagerClient).to receive(:new).and_return(client_1, client_2)
        allow(client_1).to receive(:enable_secrets_engine)
        allow(client_2).to receive(:enable_secrets_engine)
      end

      it 'enables the secret engine for the project' do
        expect { perform_idempotent_work }.not_to raise_error

        expect(secrets_manager.reload).to be_active
      end
    end
  end
end
