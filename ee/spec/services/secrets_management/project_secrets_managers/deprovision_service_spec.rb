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

  describe '#initialize' do
    let(:stored_namespace_path) { ['group', group.id.to_s].join('_') }
    let(:stored_project_path) { "project_#{project.id}" }

    context 'when only namespace_path is nil' do
      before do
        secrets_manager.update!(
          namespace_path: nil,
          project_path: stored_project_path
        )
      end

      it 'builds namespace_path and keeps stored project_path' do
        expected_namespace_path = [project.namespace.type.downcase, project.namespace.id].join('_')

        # trigger initialization
        service

        expect(service.instance_variable_get(:@namespace_path)).to eq(expected_namespace_path)
        expect(service.instance_variable_get(:@project_path)).to eq(stored_project_path)
      end
    end

    context 'when only project_path is nil' do
      before do
        secrets_manager.update!(
          namespace_path: stored_namespace_path,
          project_path: nil
        )
      end

      it 'keeps stored namespace_path and builds project_path' do
        expected_project_path = "project_#{project.id}"

        # trigger initialization
        service

        expect(service.instance_variable_get(:@namespace_path)).to eq(stored_namespace_path)
        expect(service.instance_variable_get(:@project_path)).to eq(expected_project_path)
      end
    end

    context 'when both namespace_path and project_path are nil' do
      before do
        secrets_manager.update!(namespace_path: nil, project_path: nil)
      end

      it 'builds both namespace_path and project_path from the project' do
        expected_namespace_path = [project.namespace.type.downcase, project.namespace.id].join('_')
        expected_project_path   = "project_#{project.id}"

        # initialize service
        service

        expect(service.instance_variable_get(:@namespace_path)).to eq(expected_namespace_path)
        expect(service.instance_variable_get(:@project_path)).to eq(expected_project_path)
      end
    end
  end

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

      update_project_secrets_permission(
        user: user,
        project: project,
        actions: %w[read],
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

    context 'when project is nil' do
      let(:secrets_manager) do
        create(:project_secrets_manager,
          project: project,
          namespace_path: "group_#{group.id}",
          project_path: "project_#{project.id}"
        )
      end

      let(:service) do
        allow(secrets_manager).to receive(:project).and_return(nil)
        described_class.new(secrets_manager, user)
      end

      let(:global_client) { instance_double(SecretsManagement::SecretsManagerClient) }
      let(:namespaced_client) { instance_double(SecretsManagement::SecretsManagerClient) }

      before do
        # Avoid real OpenBao calls; we just want to verify the right namespace is used.
        allow(service).to receive(:global_secrets_manager_client).and_return(global_client)
        allow(global_client).to receive(:with_namespace).with("group_#{group.id}").and_return(namespaced_client)

        # Make deprovision run without touching the rest of the system
        allow(namespaced_client).to receive(:disable_namespace).and_return({})
        allow(global_client).to receive(:disable_namespace).and_return({})
        allow(secrets_manager).to receive(:destroy!).and_return(true)

        # Ensure the nil-project branch doesn't try to acquire a lease
        allow(service).to receive(:with_exclusive_lease_for).and_call_original
      end

      it 'does not try to acquire an exclusive lease and still runs deprovision', :aggregate_failures do
        # ensure we don't try to lock on a nil project
        expect(service).not_to receive(:with_exclusive_lease_for)

        # Keep this test focused on the nil-project path and not on OpenBao plumbing:
        allow(service).to receive(:execute_deprovision).and_return(ServiceResponse.success)

        expect(result).to be_success
      end

      it 'uses global_secrets_manager_client.with_namespace(namespace_path) for the namespace client',
        :aggregate_failures do
        expect(global_client).to receive(:with_namespace).with("group_#{group.id}").and_return(namespaced_client)
        expect(namespaced_client).to receive(:disable_namespace).with("project_#{project.id}").at_least(:once)

        expect(service.execute).to be_success
      end
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
        secrets_manager.policy_name_for_principal(
          principal_type: 'Role',
          principal_id: Gitlab::Access.sym_options_with_owner[:owner]
        ))

      # Member role policy (created by update_project_secrets_permission)
      expect_policy_to_exist(
        secrets_manager.full_project_namespace_path,
        secrets_manager.policy_name_for_principal(
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
          another_secrets_manager.policy_name_for_principal(
            principal_type: 'Role',
            principal_id: Gitlab::Access.sym_options_with_owner[:owner]
          ))
        expect(another_secrets_manager.reload).to be_present
      end
    end
  end
end
