# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Permissions::ListService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:test_group) { create(:group) }
  let!(:project_group_link) do
    create(:project_group_link, project: project, group: test_group, group_access: Gitlab::Access::DEVELOPER)
  end

  let(:service) { described_class.new(project, user) }

  before_all do
    project.add_owner(user)
  end

  subject(:result) { service.execute }

  describe '#execute' do
    context 'when secrets manager is active' do
      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when there are no secret permissions' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:secret_permissions]).to eq([])
        end
      end

      context 'when there are secret permissions' do
        let_it_be(:member_role) { create(:member_role, :guest, namespace: project.group) }

        before do
          update_secret_permission(
            user: user, project: project, permissions: %w[create update read], principal: { id: user.id, type: 'User' }
          )
          update_secret_permission(
            user: user, project: project, permissions: %w[create update read], principal: { id: 2, type: 'Role' }
          )
          update_secret_permission(
            user: user, project: project, permissions: %w[create update
              read], principal: { id: member_role.id, type: 'MemberRole' }
          )
          update_secret_permission(
            user: user, project: project, permissions: %w[create update
              read], principal: { id: test_group.id, type: 'Group' }
          )
        end

        it 'returns all secret permissions' do
          expect(result).to be_success

          secret_permissions = result.payload[:secret_permissions]
          expect(secret_permissions.size).to eq(4)
        end
      end
    end

    context 'when secrets manager is not active' do
      it 'returns an error' do
        result = service.execute
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end
end
