# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }

  subject(:secrets_manager) { create(:group_secrets_manager, group: group) }

  it { is_expected.to belong_to(:group) }

  it { is_expected.to validate_presence_of(:group) }

  it_behaves_like 'a secrets manager'

  describe '#ci_policy_name_for_environment' do
    it 'returns protected environment-based policy for non-wildcard environments' do
      environment = 'production'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/env/#{environment.unpack1('H*')}")
    end

    it 'returns unprotected environment-based policy for non-wildcard environments' do
      environment = 'production'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: false))
        .to eq("pipelines/combined/unprotected/env/#{environment.unpack1('H*')}")
    end

    it 'returns protected global policy for wildcard environment' do
      environment = '*'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/global")
    end

    it 'returns unprotected global policy for wildcard environment' do
      environment = '*'

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: false))
        .to eq("pipelines/combined/unprotected/global")
    end

    it 'handles special characters in environment names' do
      environment = 'staging/us-east-1'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_for_environment(environment, protected: true))
        .to eq("pipelines/combined/protected/env/#{hex_env}")
    end
  end

  describe '#full_group_namespace_path' do
    subject(:path) { secrets_manager.full_group_namespace_path }

    context 'for a root group' do
      it 'returns the group path nested under itself' do
        expect(path).to eq("group_#{group.id}/group_#{group.id}")
      end
    end

    context 'for a nested group' do
      let_it_be(:parent_group) { create(:group) }

      before do
        group.parent = parent_group
        group.save!
      end

      it 'includes both root parent and group paths' do
        expect(path).to eq("group_#{parent_group.id}/group_#{group.id}")
      end
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }

      before do
        group.parent = subgroup_a
        group.save!
      end

      it 'includes itself and only the root parent namespace path' do
        expect(path).to eq("group_#{root_group.id}/group_#{group.id}")
      end
    end
  end

  describe '#root_namespace_path' do
    subject(:path) { secrets_manager.root_namespace_path }

    context 'for a root group' do
      it 'returns the group path' do
        expect(path).to eq("group_#{group.id}")
      end
    end

    context 'for a nested group' do
      let_it_be(:parent_group) { create(:group) }

      before do
        group.parent = parent_group
        group.save!
      end

      it 'returns only the root group path' do
        expect(path).to eq("group_#{parent_group.id}")
      end
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }

      before do
        group.parent = subgroup_a
        group.save!
      end

      it 'returns only the root group path' do
        expect(path).to eq("group_#{root_group.id}")
      end
    end
  end

  describe '#group_path' do
    subject(:path) { secrets_manager.group_path }

    context 'for a root group' do
      it 'returns the group path' do
        expect(path).to eq("group_#{group.id}")
      end
    end

    context 'for a nested group' do
      let_it_be(:parent_group) { create(:group) }

      before do
        group.parent = parent_group
        group.save!
      end

      it 'returns only the group path without the parent group' do
        expect(path).to eq("group_#{group.id}")
      end
    end

    context 'for a deeply nested group' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup_a) { create(:group, parent: root_group) }

      before do
        group.parent = subgroup_a
        group.save!
      end

      it 'returns only the group path without the nested groups' do
        expect(path).to eq("group_#{group.id}")
      end
    end
  end

  describe '#ci_secrets_mount_full_path' do
    let(:path) { secrets_manager.ci_secrets_mount_full_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_group_namespace_path: 'some/namespace/group_1',
        ci_secrets_mount_path: 'secrets/kv'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/group_1/secrets/kv')
    end
  end

  describe '#ci_auth_path' do
    let(:path) { secrets_manager.ci_auth_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_group_namespace_path: 'some/namespace/group_1',
        ci_auth_mount: 'ci_auth'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/group_1/auth/ci_auth/login')
    end
  end

  describe '#ci_jwt' do
    let_it_be(:project) { create(:project, namespace: group) }
    let(:secrets_manager) { build(:group_secrets_manager, group: group) }
    let_it_be(:ci_build) { create(:ci_build, project: project) }
    let_it_be(:openbao_server_url) { described_class.server_url }

    subject(:ci_jwt) { secrets_manager.ci_jwt(ci_build) }

    before do
      allow(SecretsManagement::PipelineJwt).to receive(:for_build)
        .with(ci_build, aud: openbao_server_url)
        .and_return("generated_jwt_id_token_for_group_secrets_manager")
    end

    it 'generates a JWT for the build' do
      expect(ci_jwt).to eq("generated_jwt_id_token_for_group_secrets_manager")
    end
  end
end
