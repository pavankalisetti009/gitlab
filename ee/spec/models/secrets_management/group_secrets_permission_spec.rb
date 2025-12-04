# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsPermission, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:principal_type) { 'User' }
  let(:principal_id) { user.id }

  subject(:permission) do
    described_class.new(
      resource: group,
      principal_type: principal_type,
      principal_id: principal_id,
      permissions: %w[create read]
    )
  end

  before_all do
    group.add_maintainer(user)
  end

  before do
    provision_group_secrets_manager(secrets_manager, user)
  end

  it_behaves_like 'a secrets permission'

  describe 'group-specific validations' do
    context 'when there is no active secrets manager' do
      it 'is invalid' do
        deprovision_group_secrets_manager(secrets_manager, user)
        group.reload
        expect(permission).not_to be_valid
        expect(permission.errors[:base]).to include('Group secrets manager is not active.')
      end
    end

    context 'when principal_type is Group' do
      let(:principal_type) { 'Group' }

      context 'when principal is the same group' do
        let(:principal_id) { group.id }

        it { is_expected.to be_valid }
      end

      context 'when principal is a parent group' do
        let(:parent_group) { create(:group) }
        let(:principal_id) { parent_group.id }

        before do
          group.update!(parent: parent_group)
        end

        it { is_expected.to be_valid }
      end

      context 'when principal is a child group' do
        let!(:child_group) { create(:group, parent: group) }
        let(:principal_id) { child_group.id }

        it { is_expected.to be_valid }
      end

      context 'when principal is a shared group' do
        let(:shared_group) { create(:group) }
        let(:principal_id) { shared_group.id }

        before do
          create(:group_group_link, shared_group: group, shared_with_group: shared_group)
        end

        it { is_expected.to be_valid }
      end

      context 'when principal group has no relationship' do
        let!(:unrelated_group) { create(:group) }
        let(:principal_id) { unrelated_group.id }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('group does not have access to this group')
        end
      end
    end

    context 'when principal_type is MemberRole' do
      let(:principal_type) { 'MemberRole' }
      let(:principal_id) { member_role.id }

      context 'with a valid member role for the group' do
        let(:member_role) { create(:member_role, namespace: group) }

        it { is_expected.to be_valid }
      end

      context 'with a valid member role from parent group' do
        let(:parent_group) { create(:group) }
        let(:member_role) { create(:member_role, namespace: parent_group) }

        before do
          group.update!(parent: parent_group)
        end

        it { is_expected.to be_valid }
      end

      context 'with an invalid member role from unrelated group' do
        let(:another_group) { create(:group) }
        let(:member_role) { create(:member_role, namespace: another_group) }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Member Role does not have access to this group')
        end
      end

      context 'with non-existent member role' do
        let(:principal_id) { 999999 }

        it 'is invalid' do
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Member Role does not exist')
        end
      end
    end
  end
end
