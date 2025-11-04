# frozen_string_literal: true

require 'spec_helper'
RSpec.describe SecretsManagement::ProjectSecretsManagers::DeprovisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, owner_of: project) }
  let_it_be(:member_user) { create(:user) }
  let_it_be(:member_role) { create(:member_role, namespace: group) }

  let_it_be(:group_member) do
    create(:group_member, {
      user: member_user,
      group: member_role.namespace,
      access_level: Gitlab::Access::DEVELOPER,
      member_role: member_role
    })
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager, user) }

  subject(:result) { service.execute }

  describe '#execute', :aggregate_failures do
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

      update_secret_permission(
        user: user,
        project: project,
        permissions: %w[read],
        principal: { id: member_role.id, type: 'MemberRole' }
      )

      # TODO: This is temporary, we just add this here to simulate left-over jwt non-CEL role in production
      # that needs to be cleaned up when running this service. In the next milestone, let's remove
      # this and related code in the service. Expectation is that user auth mounts will only have CEL role.
      client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
      client.update_jwt_role(
        secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role,
        bound_claims: {
          project_id: project.id.to_s
        },
        role_type: 'jwt',
        user_claim: "user_id",
        token_type: "service"
      )
    end

    it 'deletes all resources related to the project secrets manager' do
      # Verify resources exist before deletion
      expect_jwt_role_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount,
        secrets_manager.ci_auth_role)
      expect_jwt_role_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role)
      expect_jwt_cel_role_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role)
      expect_jwt_auth_engine_to_be_mounted(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount)
      expect_jwt_auth_engine_to_be_mounted(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount)
      expect_kv_secret_engine_to_be_mounted(secrets_manager.full_project_namespace_path,
        secrets_manager.ci_secrets_mount_path)

      # Verify policies exist before deletion using the model's policy name generators
      # Pipeline policies (created when secret is created with dev-* and development)
      expect_policy_to_exist(secrets_manager.full_project_namespace_path,
        secrets_manager.ci_policy_name('dev-*', 'development'))

      # Owner role policy (created by provision service)
      expect_policy_to_exist(
        secrets_manager.full_project_namespace_path,
        secrets_manager.generate_policy_name(
          principal_type: 'Role',
          principal_id: Gitlab::Access.sym_options_with_owner[:owner]
        ))

      # Member role policy (created by update_secret_permission)
      expect_policy_to_exist(
        secrets_manager.full_project_namespace_path,
        secrets_manager.generate_policy_name(
          principal_type: 'MemberRole',
          principal_id: member_role.id
        ))

      expect(result).to be_success

      # Verify JWT roles are deleted
      expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount,
        secrets_manager.ci_auth_role)
      expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role)
      expect_jwt_cel_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role)

      # Auth engines should be deleted
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

    it_behaves_like 'an operation requiring an exclusive project secret operation lease', 120.seconds

    context 'when multiple projects share the same namespace' do
      let!(:another_project) { create(:project, namespace: project.namespace) }

      let(:another_secrets_manager) do
        create(:project_secrets_manager, project: another_project)
      end

      before do
        provision_project_secrets_manager(another_secrets_manager, user)
      end

      it 'only deletes this project resources without affecting other projects' do
        expect_jwt_role_to_exist(
          another_secrets_manager.full_project_namespace_path,
          another_secrets_manager.ci_auth_mount,
          another_secrets_manager.ci_auth_role
        )

        expect(result).to be_success

        # This project's resources should be deleted
        expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role)
        expect_jwt_role_not_to_exist(secrets_manager.full_project_namespace_path, secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role)
        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path)
        expect_project_to_have_no_policies(secrets_manager.full_project_namespace_path)
        expect(SecretsManagement::ProjectSecretsManager.find_by(id: secrets_manager.id)).to be_nil

        # Auth engines should be deleted
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount)
        expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_project_namespace_path,
          secrets_manager.user_auth_mount)

        # Other project's JWT roles should still exist
        expect_jwt_role_to_exist(
          another_secrets_manager.full_project_namespace_path,
          another_secrets_manager.ci_auth_mount,
          another_secrets_manager.ci_auth_role
        )

        # Other project's secrets engine should still exist
        expect_kv_secret_engine_to_be_mounted(another_secrets_manager.full_project_namespace_path,
          another_secrets_manager.ci_secrets_mount_path)

        # Other project's policies should still exist
        expect_policy_to_exist(
          another_secrets_manager.full_project_namespace_path,
          another_secrets_manager.generate_policy_name(
            principal_type: 'Role',
            principal_id: Gitlab::Access.sym_options_with_owner[:owner]
          ))
        expect(another_secrets_manager.reload).to be_present
      end
    end
  end

  context 'when cleaning up a legacy project' do
    let!(:another_project) { create(:project, namespace: project.namespace) }
    let(:another_service) { described_class.new(another_project.secrets_manager, user) }

    before do
      # Create a secrets manager database object manually.
      another_project.secrets_manager = SecretsManagement::ProjectSecretsManager.create!(project: another_project)
      another_project.secrets_manager.status = SecretsManagement::ProjectSecretsManager::STATUSES[:active]
      another_project.secrets_manager.save!

      # Create legacy auth mounts
      secrets_manager_client.enable_auth_engine(another_project.secrets_manager.legacy_ci_auth_mount, "jwt")
      secrets_manager_client.enable_auth_engine(another_project.secrets_manager.legacy_user_auth_mount, "jwt")

      # Create legacy secrets mounts
      secrets_manager_client.enable_secrets_engine(another_project.secrets_manager.legacy_ci_secrets_mount_path,
        "kv-v2")

      # Create a legacy policy
      secrets_manager_client.set_policy(SecretsManagement::AclPolicy.new("project_#{project.id}/pipelines/global"))
    end

    subject(:another_result) { another_service.execute }

    it 'removes legacy mounts' do
      expect(another_result).to be_success

      # Auth engines should be deleted
      expect_jwt_auth_engine_not_to_be_mounted("", another_project.secrets_manager.legacy_ci_auth_mount)
      expect_jwt_auth_engine_not_to_be_mounted("", another_project.secrets_manager.legacy_user_auth_mount)

      # Secrets engine should be deleted
      expect_kv_secret_engine_not_to_be_mounted("", another_project.secrets_manager.legacy_ci_secrets_mount_path)

      # Expect there to be no policies
      expect_legacy_project_to_have_no_policies(another_project)
    end
  end
end
