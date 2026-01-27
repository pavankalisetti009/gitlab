# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UserAccess, feature_category: :permissions do
  include ExternalAuthorizationServiceHelpers

  let_it_be_with_reload(:user) { create(:user) }

  subject(:access) { described_class.new(user, container: project) }

  describe '#can_push_to_branch?' do
    describe 'push to empty project' do
      let_it_be(:project) { create(:project_empty_repo) }

      it 'returns false when the external service denies access' do
        project.add_maintainer(user)
        external_service_deny_access(user, project)

        expect(access.can_push_to_branch?('master')).to be_falsey
      end
    end
  end

  describe '#can_delete_branch?' do
    context 'when a user has custom roles with `admin_protected_branch` assigned' do
      let_it_be(:project) { create(:project, :repository, :in_group) }

      let_it_be(:role) { create(:member_role, :developer, :admin_protected_branch, namespace: project.group) }
      let_it_be(:project_member) do
        create(:project_member, :developer, member_role: role, user: user, project: project)
      end

      describe 'delete protected branch' do
        let_it_be(:branch) { create(:protected_branch, project: project, name: "test") }

        context 'when custom roles is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'returns true' do
            expect(access.can_delete_branch?(branch.name)).to be(true)
          end
        end

        context 'when custom roles is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'returns false' do
            expect(access.can_delete_branch?(branch.name)).to be(false)
          end
        end
      end
    end
  end
end
