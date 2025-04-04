# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManager, feature_category: :secrets_management do
  subject(:secrets_manager) { build(:project_secrets_manager) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }

  describe 'state machine' do
    context 'when newly created' do
      it 'defaults to provisioning' do
        secrets_manager.save!
        expect(secrets_manager).to be_provisioning
      end
    end

    context 'when activated' do
      it 'becomes active' do
        secrets_manager.save!
        secrets_manager.activate!
        expect(secrets_manager.reload).to be_active
      end
    end
  end

  describe '#ci_secrets_mount_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_secrets_mount_path }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end
  end

  describe '#ci_data_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_data_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end
  end

  describe '#ci_full_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_full_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end
  end

  describe '#ci_jwt' do
    let_it_be(:project) { create(:project) }
    let_it_be(:secrets_manager) { build(:project_secrets_manager, project: project) }
    let_it_be(:ci_build) { create(:ci_build, project: project) }
    let_it_be(:openbao_server_url) { described_class.server_url }

    subject(:ci_jwt) { secrets_manager.ci_jwt(ci_build) }

    before do
      allow(Gitlab::Ci::JwtV2).to receive(:for_build).with(ci_build, aud: openbao_server_url)
      .and_return("generated_jwt_id_token_for_secrets_manager")
    end

    it 'generates a JWT for the build' do
      expect(ci_jwt).to eq("generated_jwt_id_token_for_secrets_manager")
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'generate_id_token_for_secrets_manager_authentication' }
      let(:category) { described_class.name }
      let(:namespace) { project.namespace }
      let(:user) { ci_build.user }
    end
  end

  describe 'policy name generation' do
    let_it_be(:project) { create(:project) }

    subject(:test_subject) do
      described_class.new.send(:generate_policy_name, project_id: project.id, principal_type: principal_type,
        principal_id: principal_id)
    end

    context 'for User principal type' do
      let(:principal_type) { 'User' }
      let(:principal_id) { 123 }

      it 'generates the correct policy name' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/user_123")
      end
    end

    context 'for Role principal type' do
      let(:principal_type) { 'Role' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with role ID' do
        expect(test_subject).to eq("project_#{project.id}/users/roles/3")
      end
    end

    context 'for MemberRole principal type' do
      let(:principal_type) { 'MemberRole' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with member role ID' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/member_role_3")
      end
    end

    context 'for Group principal type' do
      let(:principal_type) { 'Group' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with group ID' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/group_3")
      end
    end
  end
end
