# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ListService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:include_rotation_info) { true }

  describe '#execute' do
    let(:user) { create(:user, owner_of: project) }

    subject(:result) { service.execute(include_rotation_info: include_rotation_info) }

    context 'when secrets manager is active and user is owner' do
      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when there are no secrets' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:project_secrets]).to eq([])
        end
      end

      context 'when there are secrets' do
        before do
          create_project_secret(
            user: user,
            project: project,
            name: 'SECRET1',
            description: 'First secret',
            branch: 'main',
            environment: 'production',
            value: 'secret-value-1'
          )

          create_project_secret(
            user: user,
            project: project,
            name: 'SECRET2',
            description: 'Second secret',
            branch: 'staging',
            environment: 'staging',
            value: 'secret-value-2',
            rotation_interval_days: 30
          )
        end

        it 'returns all secrets' do
          expect(result).to be_success

          secrets = result.payload[:project_secrets]
          expect(secrets.size).to eq(2)

          expect(secrets.map(&:name)).to match_array(%w[SECRET1 SECRET2])

          # Verify a few properties of each secret
          secret1 = secrets.find { |s| s.name == 'SECRET1' }
          expect(secret1.description).to eq('First secret')
          expect(secret1.branch).to eq('main')
          expect(secret1.environment).to eq('production')
          expect(secret1.metadata_version).to eq(1)
          expect(secret1.rotation_info).to be_nil

          secret2 = secrets.find { |s| s.name == 'SECRET2' }
          expect(secret2.description).to eq('Second secret')
          expect(secret2.branch).to eq('staging')
          expect(secret2.environment).to eq('staging')
          expect(secret2.metadata_version).to eq(1)

          rotation_info = secret_rotation_info_for_project_secret(project, secret2.name, secret2.metadata_version)
          expect(secret2.rotation_info).to eq(rotation_info)
        end

        context 'and include_rotation_info is false' do
          let(:include_rotation_info) { false }

          it 'does not include the rotation info in the result' do
            expect(result).to be_success

            secrets = result.payload[:project_secrets]
            expect(secrets.size).to eq(2)

            expect(secrets.filter_map(&:rotation_info)).to be_empty
          end
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect(result).to be_error
        expect(result.message).to eq("1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when user is a developer and has proper permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secrets]).to eq([])
      end
    end

    context 'when user has a member role and has proper permissions' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }

      let!(:member_role) { create(:member_role, namespace: project.group) }
      let!(:group_member) do
        create(:group_member, {
          user: user,
          group: member_role.namespace,
          access_level: Gitlab::Access::DEVELOPER,
          member_role: member_role
        })
      end

      let(:user) { create(:user) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[
            read
          ], principal: { id: member_role.id, type: 'MemberRole' }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secrets]).to eq([])
      end
    end

    context 'when user has a member role and has no permissions' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }

      let!(:member_role) { create(:member_role, namespace: project.group) }
      let!(:group_member) do
        create(:group_member, {
          user: user,
          group: member_role.namespace,
          access_level: Gitlab::Access::DEVELOPER,
          member_role: member_role
        })
      end

      let(:user) { create(:user) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq("1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when secrets manager is not active' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Project secrets manager is not active')
      end
    end
  end
end
