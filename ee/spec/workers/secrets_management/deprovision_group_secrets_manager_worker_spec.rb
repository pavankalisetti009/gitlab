# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::DeprovisionGroupSecretsManagerWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user, owner_of: group) }

    let(:secrets_manager) { create(:group_secrets_manager, group: group) }

    before do
      provision_group_secrets_manager(secrets_manager, user)
    end

    it 'executes a service' do
      expect(SecretsManagement::GroupSecretsManager)
        .to receive(:find_by_id).with(secrets_manager.id).and_return(secrets_manager)

      expect(User).to receive(:find_by_id).with(user.id).and_return(user)

      service = instance_double(SecretsManagement::GroupSecretsManagers::DeprovisionService)
      expect(SecretsManagement::GroupSecretsManagers::DeprovisionService)
        .to receive(:new).with(secrets_manager, user).and_return(service)

      expect(service).to receive(:execute)

      worker.perform(user.id, secrets_manager.id)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [user.id, secrets_manager.id] }

      it 'completely deprovisions the group secrets manager' do
        expect { perform_idempotent_work }.not_to raise_error

        # Verify JWT roles are deleted
        expect_jwt_cel_role_not_to_exist(secrets_manager.full_group_namespace_path, secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role)
        expect_jwt_cel_role_not_to_exist(secrets_manager.full_group_namespace_path, secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role)

        # Auth engines are deleted
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount)
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_group_namespace_path,
          secrets_manager.user_auth_mount)

        # Secrets engine should be deleted
        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path)

        # All policies should be deleted
        expect_group_to_have_no_policies(secrets_manager.full_group_namespace_path)

        # Verify the secrets manager record is deleted
        expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
      end
    end

    context 'when group secrets manager does not exist' do
      it 'does nothing' do
        expect(SecretsManagement::GroupSecretsManagers::DeprovisionService).not_to receive(:new)

        non_existent_secrets_manager_id = SecretsManagement::GroupSecretsManager.count + 1
        worker.perform(user.id, non_existent_secrets_manager_id)
      end
    end

    context 'when user does not exist' do
      it 'does nothing' do
        expect(SecretsManagement::GroupSecretsManagers::DeprovisionService).not_to receive(:new)

        non_existent_user_id = User.count + 1
        worker.perform(non_existent_user_id, secrets_manager.id)
      end
    end

    context 'when partial failures occur' do
      let(:job_args) { [user.id, secrets_manager.id] }

      context 'when JWT roles are already deleted' do
        before do
          # Simulate JWT roles already being deleted
          client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
          client.delete_jwt_cel_role(
            secrets_manager.ci_auth_mount,
            secrets_manager.ci_auth_role
          )
          client.delete_jwt_cel_role(
            secrets_manager.user_auth_mount,
            secrets_manager.user_auth_role
          )
        end

        it 'completes successfully on retry' do
          expect { worker.perform(user.id, secrets_manager.id) }.not_to raise_error

          # Verify complete deletion
          expect(SecretsManagement::GroupSecretsManager.find_by_id(secrets_manager.id)).to be_nil
          expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_group_namespace_path,
            secrets_manager.ci_secrets_mount_path)
          expect_group_to_have_no_policies(secrets_manager.full_group_namespace_path)
        end
      end

      context 'when secrets engine is already deleted' do
        before do
          # Simulate secrets engine already being deleted
          client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
          client.disable_secrets_engine(secrets_manager.ci_secrets_mount_path)
        end

        it 'completes successfully on retry' do
          expect { worker.perform(user.id, secrets_manager.id) }.not_to raise_error

          # Verify complete deletion including DB record
          expect(SecretsManagement::GroupSecretsManager.find_by_id(secrets_manager.id)).to be_nil
          expect_jwt_cel_role_not_to_exist(secrets_manager.full_group_namespace_path, secrets_manager.ci_auth_mount,
            secrets_manager.ci_auth_role)
          expect_jwt_cel_role_not_to_exist(secrets_manager.full_group_namespace_path,
            secrets_manager.user_auth_mount, secrets_manager.user_auth_role)
        end
      end

      context 'when the secrets manager record is already deleted but OpenBao resources remain' do
        it 'handles the case where the record is not found' do
          # Store the data we need before deletion
          ci_auth_mount = secrets_manager.ci_auth_mount
          ci_auth_role = secrets_manager.ci_auth_role
          user_auth_mount = secrets_manager.user_auth_mount
          user_auth_role = secrets_manager.user_auth_role
          ci_secrets_mount_path = secrets_manager.ci_secrets_mount_path

          # Delete the DB record but leave OpenBao resources
          secrets_manager.destroy!
          # The worker should handle the missing record gracefully
          expect { worker.perform(user.id, secrets_manager.id) }.not_to raise_error

          # OpenBao resources should remain since the service wasn't executed
          expect_jwt_cel_role_to_exist(secrets_manager.full_group_namespace_path, ci_auth_mount, ci_auth_role)
          expect_jwt_cel_role_to_exist(secrets_manager.full_group_namespace_path, user_auth_mount, user_auth_role)
          expect_kv_secret_engine_to_be_mounted(secrets_manager.full_group_namespace_path, ci_secrets_mount_path)
        end
      end

      context 'when everything is already deleted' do
        before do
          # Fully delete everything first
          SecretsManagement::GroupSecretsManagers::DeprovisionService.new(secrets_manager, user).execute
        end

        it 'handles repeated execution gracefully' do
          # The worker should handle the missing record
          expect { worker.perform(user.id, secrets_manager.id) }.not_to raise_error
        end
      end
    end
  end
end
