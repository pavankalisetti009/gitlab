# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::DeprovisionProjectSecretsManagerByPathWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, owner_of: project) }
    let_it_be(:member_role) { create(:member_role, namespace: group) }

    let(:secrets_manager) { create(:project_secrets_manager, project: project) }

    let(:namespace_path) { secrets_manager.namespace_path }
    let(:project_path)   { secrets_manager.project_path }

    before do
      provision_project_secrets_manager(secrets_manager, user)

      create_project_secret(
        user: user,
        project: project,
        name: 'TEST_SECRET',
        branch: 'development',
        environment: 'dev-*',
        value: 'test'
      )

      update_project_secrets_permission(
        user: user,
        project: project,
        actions: %w[read],
        principal: { id: member_role.id, type: 'MemberRole' }
      )
    end

    context 'when the user does not exist' do
      it 'returns early and does not call the service' do
        # user has been deleted (or never existed)
        user_id = non_existing_record_id # or user.id.tap { user.destroy! }

        expect(User).to receive(:find_by_id).with(user_id).and_return(nil)
        expect(SecretsManagement::ProjectSecretsManager).not_to receive(:find_by_id)
        expect(SecretsManagement::ProjectSecretsManagers::DeprovisionService).not_to receive(:new)

        worker.perform(user_id, secrets_manager.id, namespace_path, project_path)
      end
    end

    it 'executes the service with paths' do
      expect(SecretsManagement::ProjectSecretsManager)
        .to receive(:find_by_id).with(secrets_manager.id).and_return(secrets_manager)

      expect(User).to receive(:find_by_id).with(user.id).and_return(user)

      service = instance_double(SecretsManagement::ProjectSecretsManagers::DeprovisionService)
      expect(SecretsManagement::ProjectSecretsManagers::DeprovisionService)
        .to receive(:new)
        .with(secrets_manager, user, namespace_path: namespace_path, project_path: project_path)
        .and_return(service)

      expect(service).to receive(:execute)

      worker.perform(user.id, secrets_manager.id, namespace_path, project_path)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [user.id, secrets_manager.id, namespace_path, project_path] }

      it 'completely deprovisions the project secrets manager' do
        expect { perform_idempotent_work }.not_to raise_error

        # Verify JWT roles are deleted
        expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role)
        expect_jwt_cel_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role)

        # Auth engines are deleted
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount)
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.user_auth_mount)

        # Secrets engine should be deleted
        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path)

        # All policies should be deleted
        expect_project_to_have_no_policies(secrets_manager.full_project_namespace_path)

        # Verify the secrets manager record is deleted
        expect(SecretsManagement::ProjectSecretsManager.find_by(id: secrets_manager.id)).to be_nil
      end
    end

    context 'when partial failures occur' do
      let(:job_args) { [user.id, secrets_manager.id, namespace_path, project_path] }

      context 'when JWT roles are already deleted' do
        before do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.delete_jwt_role(
            secrets_manager.ci_auth_mount,
            secrets_manager.ci_auth_role
          )
          client.delete_jwt_cel_role(
            secrets_manager.user_auth_mount,
            secrets_manager.user_auth_role
          )
        end

        it 'completes successfully on retry' do
          expect { worker.perform(user.id, secrets_manager.id, namespace_path, project_path) }.not_to raise_error

          expect(SecretsManagement::ProjectSecretsManager.find_by_id(secrets_manager.id)).to be_nil
          expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
            secrets_manager.ci_secrets_mount_path)
          expect_project_to_have_no_policies(secrets_manager.full_project_namespace_path)
        end
      end

      context 'when secrets engine is already deleted' do
        before do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.disable_secrets_engine(secrets_manager.ci_secrets_mount_path)
        end

        it 'completes successfully on retry' do
          expect { worker.perform(user.id, secrets_manager.id, namespace_path, project_path) }.not_to raise_error

          expect(SecretsManagement::ProjectSecretsManager.find_by_id(secrets_manager.id)).to be_nil
          expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount,
            secrets_manager.ci_auth_role)
          expect_jwt_cel_role_not_to_exist(secrets_manager.full_project_namespace_path,
            secrets_manager.user_auth_mount, secrets_manager.user_auth_role)
        end
      end

      context 'when the secrets manager record is already deleted but OpenBao resources remain' do
        it 'handles the case where the record is not found' do
          ci_auth_mount = secrets_manager.ci_auth_mount
          ci_auth_role = secrets_manager.ci_auth_role
          user_auth_mount = secrets_manager.user_auth_mount
          user_auth_role = secrets_manager.user_auth_role
          ci_secrets_mount_path = secrets_manager.ci_secrets_mount_path

          secrets_manager.destroy!

          expect { worker.perform(user.id, secrets_manager.id, namespace_path, project_path) }.not_to raise_error

          expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, ci_auth_mount, ci_auth_role)
          expect_jwt_cel_role_not_to_exist(secrets_manager.full_project_namespace_path, user_auth_mount, user_auth_role)
          expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path, ci_secrets_mount_path)
        end
      end

      context 'when everything is already deleted' do
        before do
          ::SecretsManagement::ProjectSecretsManagers::DeprovisionService
            .new(secrets_manager, user, namespace_path: namespace_path, project_path: project_path)
            .execute
        end

        it 'handles repeated execution gracefully' do
          expect { worker.perform(user.id, secrets_manager.id, namespace_path, project_path) }.not_to raise_error
        end
      end
    end
  end
end
