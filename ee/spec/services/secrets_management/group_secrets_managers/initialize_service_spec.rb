# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagers::InitializeService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(group, user) }

  subject(:result) { service.execute }

  describe '#execute' do
    let(:provision_worker_spy) { class_spy(SecretsManagement::ProvisionGroupSecretsManagerWorker) }

    before do
      stub_const('SecretsManagement::ProvisionGroupSecretsManagerWorker', provision_worker_spy)
    end

    context 'when the group has no secrets manager' do
      it 'creates a secrets manager record for the group', :aggregate_failures do
        expect(result).to be_success

        secrets_manager = result.payload[:group_secrets_manager]
        expect(secrets_manager).to be_present
        expect(secrets_manager).to be_provisioning

        expect(provision_worker_spy).to have_received(:perform_async).with(user.id, secrets_manager.id)
      end
    end

    context 'when the group has a secrets manager' do
      it 'fails' do
        create(:group_secrets_manager, group: group)
        group.reload

        expect(result).to be_error
        expect(result.message).to eq('Secrets manager already initialized for the group.')
        expect(provision_worker_spy).not_to have_received(:perform_async)
      end
    end
  end
end
