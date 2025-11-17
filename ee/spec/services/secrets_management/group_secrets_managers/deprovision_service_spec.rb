# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagers::DeprovisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:service) { described_class.new(secrets_manager, user) }

  describe '#execute' do
    subject(:result) { service.execute }

    before do
      provision_group_secrets_manager(secrets_manager, user)
    end

    it 'deletes all resources related to the group secrets manager', :aggregate_failures do
      expect(result).to be_success
      expect(result.payload[:group_secrets_manager]).to eq(secrets_manager)

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

      # Namespaces should be deleted
      expect_namespace_not_to_exist(secrets_manager.full_group_namespace_path)
      expect_namespace_not_to_exist(secrets_manager.root_namespace_path)

      # Verify the secrets manager record is deleted
      expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
    end

    it_behaves_like 'an operation requiring an exclusive group secret operation lease', 120.seconds

    context 'when group namespace has child namespaces' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let(:subgroup_secrets_manager) { create(:group_secrets_manager, group: subgroup) }

      before do
        provision_group_secrets_manager(subgroup_secrets_manager, user)
      end

      it 'only deprovisions the namespace for the group' do
        result = service.execute

        expect(result).to be_success

        expect_namespace_not_to_exist(secrets_manager.full_group_namespace_path)

        expect_namespace_to_exist(secrets_manager.root_namespace_path)
        expect_namespace_to_exist(subgroup_secrets_manager.full_group_namespace_path)

        expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
        expect(SecretsManagement::GroupSecretsManager.find_by(id: subgroup_secrets_manager.id)).to be_present
      end
    end

    context 'when group is a child namespace with sibling namespaces' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:sibling_group) { create(:group, parent: group) }
      let(:sibling_secrets_manager) { create(:group_secrets_manager, group: sibling_group) }

      before do
        group.parent = parent_group
        group.save!

        provision_group_secrets_manager(sibling_secrets_manager, user)
      end

      it 'only deprovisions the namespace for the group' do
        result = service.execute

        expect(result).to be_success

        expect_namespace_not_to_exist(secrets_manager.full_group_namespace_path)

        expect_namespace_to_exist(secrets_manager.root_namespace_path)
        expect_namespace_to_exist(sibling_secrets_manager.full_group_namespace_path)

        expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
        expect(SecretsManagement::GroupSecretsManager.find_by(id: sibling_secrets_manager.id)).to be_present
      end
    end
  end
end
