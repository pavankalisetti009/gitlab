# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  subject(:secrets_manager) { create(:project_secrets_manager, project: project) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }

  it_behaves_like 'a secrets manager'

  describe '#ci_policy_name' do
    it 'returns combined policy when both environment and branch are specified' do
      expect(secrets_manager.ci_policy_name('production', 'main'))
        .to eq(secrets_manager.ci_policy_name_combined('production', 'main'))
    end

    it 'returns environment policy when only environment is specified' do
      expect(secrets_manager.ci_policy_name('production', '*'))
        .to eq(secrets_manager.ci_policy_name_env('production'))
    end

    it 'returns branch policy when only branch is specified' do
      expect(secrets_manager.ci_policy_name('*', 'main'))
        .to eq(secrets_manager.ci_policy_name_branch('main'))
    end

    it 'returns global policy when both are wildcards' do
      expect(secrets_manager.ci_policy_name('*', '*'))
        .to eq(secrets_manager.ci_policy_name_global)
    end
  end

  describe '#ci_policy_name_global' do
    it 'returns the correct global policy name' do
      expect(secrets_manager.ci_policy_name_global).to eq("pipelines/global")
    end
  end

  describe '#ci_policy_name_env' do
    it 'returns the correct environment policy name with hex-encoded environment' do
      environment = 'production'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_env(environment)).to eq("pipelines/env/#{hex_env}")
    end

    it 'handles special characters in environment names' do
      environment = 'staging/us-east-1'
      hex_env = environment.unpack1('H*')

      expect(secrets_manager.ci_policy_name_env(environment)).to eq("pipelines/env/#{hex_env}")
    end
  end

  describe '#ci_policy_name_branch' do
    it 'returns the correct branch policy name with hex-encoded branch' do
      branch = 'main'
      hex_branch = branch.unpack1('H*')

      expect(secrets_manager.ci_policy_name_branch(branch)).to eq("pipelines/branch/#{hex_branch}")
    end

    it 'handles special characters in branch names' do
      branch = 'feature/add-new-widget'
      hex_branch = branch.unpack1('H*')

      expect(secrets_manager.ci_policy_name_branch(branch)).to eq("pipelines/branch/#{hex_branch}")
    end
  end

  describe '#ci_policy_name_combined' do
    it 'returns the correct combined policy name' do
      environment = 'production'
      branch = 'main'
      hex_env = environment.unpack1('H*')
      hex_branch = branch.unpack1('H*')

      expected = "pipelines/combined/env/#{hex_env}/branch/#{hex_branch}"
      expect(secrets_manager.ci_policy_name_combined(environment, branch)).to eq(expected)
    end
  end

  describe '#ci_auth_literal_policies' do
    it 'returns an array with all policy types' do
      policies = secrets_manager.ci_auth_literal_policies

      expect(policies.size).to eq(4)
      expect(policies[0]).to eq("pipelines/global")
      expect(policies[1]).to include("pipelines/env/")
      expect(policies[2]).to include("pipelines/branch/")
      expect(policies[3]).to include("pipelines/combined/")
    end
  end

  describe '#ci_auth_glob_policies' do
    context 'with environment glob and literal branch' do
      it 'returns environment glob and combined policies' do
        policies = secrets_manager.ci_auth_glob_policies('prod-*', 'main')

        expect(policies.size).to eq(2)
        expect(policies[0]).to include("pipelines/env/")
        expect(policies[1]).to include("pipelines/combined/")
      end
    end

    context 'with literal environment and branch glob' do
      it 'returns branch glob and combined policies' do
        policies = secrets_manager.ci_auth_glob_policies('production', 'feature-*')

        expect(policies.size).to eq(2)
        expect(policies[0]).to include("pipelines/branch/")
        expect(policies[1]).to include("pipelines/combined/")
      end
    end

    context 'with both globs' do
      it 'returns all three glob policies' do
        policies = secrets_manager.ci_auth_glob_policies('prod-*', 'feature-*')

        expect(policies.size).to eq(3)
      end
    end

    context 'with no globs' do
      it 'returns an empty array' do
        policies = secrets_manager.ci_auth_glob_policies('production', 'main')

        expect(policies).to be_empty
      end
    end
  end

  describe '#full_project_namespace_path' do
    let(:path) { secrets_manager.full_project_namespace_path }

    context 'when the project belongs to a user namespace' do
      it 'includes namespace information' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}")
      end
    end

    context 'when the project belongs to a group namespace' do
      before do
        project.group = create(:group)
        project.save!
      end

      it 'includes namespace information' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}")
      end
    end
  end

  describe '#namespace_path' do
    let(:path) { secrets_manager.namespace_path }

    context 'when the project belongs to a user namespace' do
      it 'includes namespace information' do
        expect(path).to eq("user_#{project.namespace.id}")
      end
    end

    context 'when the project belongs to a group namespace' do
      before do
        project.group = create(:group)
        project.save!
      end

      it 'includes namespace information' do
        expect(path).to eq("group_#{project.namespace.id}")
      end
    end
  end

  describe '#project_path' do
    let(:path) { secrets_manager.project_path }

    it 'includes just project information' do
      expect(path).to eq("project_#{project.id}")
    end
  end

  describe '#ci_secrets_mount_full_path' do
    let(:path) { secrets_manager.ci_secrets_mount_full_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_project_namespace_path: 'some/namespace/project_1',
        ci_secrets_mount_path: 'secrets/kv'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/project_1/secrets/kv')
    end
  end

  describe '#ci_auth_path' do
    let(:path) { secrets_manager.ci_auth_path }

    before do
      allow(secrets_manager).to receive_messages(
        full_project_namespace_path: 'some/namespace/project_1',
        ci_auth_mount: 'ci_auth'
      )
    end

    it 'is returns full path including root namespace' do
      expect(path).to eq('some/namespace/project_1/auth/ci_auth/login')
    end
  end
end
