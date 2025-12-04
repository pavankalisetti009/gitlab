# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:deprovision_worker_spy) { class_spy(SecretsManagement::DeprovisionProjectSecretsManagerWorker) }

    before do
      stub_const('SecretsManagement::DeprovisionProjectSecretsManagerWorker', deprovision_worker_spy)
    end

    context 'when secrets manager exists and is active' do
      let!(:secrets_manager) { create(:project_secrets_manager, :active, project: project) }

      it 'initiates the deprovision process', :aggregate_failures do
        expect(result).to be_success

        returned_secrets_manager = result.payload[:project_secrets_manager]
        expect(returned_secrets_manager).to be_present
        expect(returned_secrets_manager).to be_deprovisioning

        expect(deprovision_worker_spy).to have_received(:perform_async).with(user.id, secrets_manager.id)
      end
    end

    context 'when secrets manager does not exist' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager not found for the project.')
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when secrets manager is not active' do
      let!(:secrets_manager) { create(:project_secrets_manager, :deprovisioning, project: project) }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end
  end
end
