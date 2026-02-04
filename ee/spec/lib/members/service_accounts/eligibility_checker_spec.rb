# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ServiceAccounts::EligibilityChecker, feature_category: :system_access do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: root_group) }

  context 'when initializing' do
    context 'with target_group' do
      it 'initializes with a group' do
        expect { described_class.new(target_group: root_group) }.not_to raise_error
      end
    end

    context 'with target_project' do
      it 'initializes with a project and extracts namespace' do
        expect { described_class.new(target_project: project) }.not_to raise_error
      end
    end

    context 'with both target_group and target_project' do
      it 'raises ArgumentError' do
        expect { described_class.new(target_group: root_group, target_project: project) }
          .to raise_error(ArgumentError, 'Cannot provide both target_group and target_project')
      end
    end

    context 'with invalid target_group type' do
      it 'raises ArgumentError' do
        expect { described_class.new(target_group: 'invalid') }
          .to raise_error(ArgumentError, 'target_group must be a Group, got String')
      end
    end

    context 'with invalid target_project type' do
      it 'raises ArgumentError' do
        expect { described_class.new(target_project: root_group) }
          .to raise_error(ArgumentError, 'target_project must be a Project, got Group')
      end
    end
  end

  describe '#eligible?' do
    subject(:eligible) { checker.eligible?(sa) }

    context 'for basic cases' do
      let(:checker) { described_class.new(target_group: target_group) }
      let(:target_group) { root_group }

      context 'with non-service account user' do
        let(:sa) { create(:user) }

        it { is_expected.to be true }
      end

      context 'with nil user' do
        let(:sa) { nil }

        it { is_expected.to be true }
      end

      context 'with nil target_group' do
        let(:target_group) { nil }
        let(:sa) { create(:user, :service_account) }

        it { is_expected.to be true }
      end
    end

    context 'with composite identity restrictions', :saas do
      let(:checker) { described_class.new(target_group: target_group) }
      let(:target_group) { root_group }

      context 'when SA is from origin group' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        it { is_expected.to be true }
      end

      context 'when SA is from subgroup of origin' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        let(:target_group) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is from unrelated group' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
        end

        it { is_expected.to be false }
      end

      context 'when SA is from unrelated subgroup' do
        let_it_be(:other_subgroup) { create(:group, parent: other_group) }
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_subgroup)
        end

        it { is_expected.to be false }
      end

      context 'when SA is from parent of origin group' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:child_origin_group) { create(:group, parent: parent_group) }
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: child_origin_group)
        end

        let(:target_group) { parent_group }

        it { is_expected.to be false }
      end

      context 'when SA does not have composite_identity_enforced' do
        let(:sa) do
          create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: other_group)
        end

        it { is_expected.to be true }
      end

      context 'when SA is instance-level (no provisioned_by_group)' do
        let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil) }

        it { is_expected.to be true }
      end
    end

    context 'with subgroup hierarchy restrictions' do
      let(:checker) { described_class.new(target_group: target_group) }
      let(:target_group) { root_group }

      context 'when SA is created in subgroup and invited to same subgroup' do
        let(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_group) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in subgroup and invited to descendant' do
        let(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_group) { nested_subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in subgroup and invited to parent' do
        let(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }

        it { is_expected.to be false }
      end

      context 'when SA is created in root group' do
        let(:sa) { create(:user, :service_account, provisioned_by_group: root_group) }
        let(:target_group) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in unrelated root group (top-level)' do
        let(:sa) { create(:user, :service_account, provisioned_by_group: other_group) }
        let(:target_group) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in unrelated subgroup' do
        let_it_be(:unrelated_subgroup) { create(:group, parent: other_group) }
        let(:sa) { create(:user, :service_account, provisioned_by_group: unrelated_subgroup) }
        let(:target_group) { subgroup }

        it { is_expected.to be false }
      end

      context 'when allow_subgroups_to_create_service_accounts is disabled' do
        before do
          stub_feature_flags(allow_subgroups_to_create_service_accounts: false)
        end

        let(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }

        it 'still applies subgroup hierarchy restrictions (FF only controls SA creation, not invite restrictions)' do
          expect(eligible).to be false
        end
      end
    end

    context 'with project-provisioned service account restrictions' do
      let_it_be(:project_in_root) { create(:project, namespace: root_group) }
      let_it_be(:project_in_subgroup) { create(:project, namespace: subgroup) }
      let_it_be(:other_project) { create(:project, namespace: other_group) }

      before do
        stub_feature_flags(allow_projects_to_create_service_accounts: true)
      end

      context 'when inviting to the origin project' do
        let(:checker) { described_class.new(target_project: project_in_root) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it { is_expected.to be true }
      end

      context 'when inviting to a different project in the same group' do
        let_it_be(:sibling_project) { create(:project, namespace: root_group) }
        let(:checker) { described_class.new(target_project: sibling_project) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it { is_expected.to be false }
      end

      context 'when inviting to a project in a different group' do
        let(:checker) { described_class.new(target_project: other_project) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it { is_expected.to be false }
      end

      context 'when inviting to a group (including parent of origin project)' do
        let(:checker) { described_class.new(target_group: root_group) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it { is_expected.to be false }
      end

      context 'when inviting to a subgroup' do
        let(:checker) { described_class.new(target_group: subgroup) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it { is_expected.to be false }
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(allow_projects_to_create_service_accounts: false)
        end

        let(:checker) { described_class.new(target_group: root_group) }
        let(:sa) do
          create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end
        end

        it 'still applies project provisioning restrictions (FF only controls SA creation, not invite restrictions)' do
          expect(eligible).to be false
        end
      end

      context 'when project belongs to personal namespace' do
        let_it_be(:personal_namespace) { create(:namespace) }
        let_it_be(:project_in_personal_namespace) { create(:project, namespace: personal_namespace) }

        before do
          stub_feature_flags(allow_projects_to_create_service_accounts: true)
        end

        context 'when inviting to the origin project' do
          let(:checker) { described_class.new(target_project: project_in_personal_namespace) }
          let(:sa) do
            create(:user, :service_account).tap do |user|
              user.user_detail.update!(provisioned_by_project_id: project_in_personal_namespace.id)
            end
          end

          it 'allows the project-provisioned SA from the same project' do
            expect(eligible).to be true
          end
        end

        context 'when inviting to a different project in the same personal namespace' do
          let_it_be(:sibling_project_in_personal_namespace) { create(:project, namespace: personal_namespace) }
          let(:checker) { described_class.new(target_project: sibling_project_in_personal_namespace) }
          let(:sa) do
            create(:user, :service_account).tap do |user|
              user.user_detail.update!(provisioned_by_project_id: project_in_personal_namespace.id)
            end
          end

          it 'prevents adding the SA to a different project' do
            expect(eligible).to be false
          end
        end

        context 'when inviting instance-level SA to project in personal namespace' do
          let(:checker) { described_class.new(target_project: project_in_personal_namespace) }
          let(:sa) { create(:user, :service_account, provisioned_by_group: nil) }

          it 'allows the instance-level SA' do
            expect(eligible).to be true
          end
        end

        context 'when inviting group-provisioned SA to project in personal namespace' do
          let(:checker) { described_class.new(target_project: project_in_personal_namespace) }
          let(:sa) { create(:user, :service_account, provisioned_by_group: root_group) }

          it 'allows the group-provisioned SA' do
            expect(eligible).to be true
          end
        end
      end
    end
  end

  describe '#filter_users' do
    context 'with mixed user types and both restrictions enabled', :saas do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'includes regular users' do
        regular_user = create(:user)

        result = checker.filter_users(User.all)

        expect(result).to include(regular_user)
      end

      it 'includes allowed SAs' do
        allowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: root_group)
        instance_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_sa, instance_sa)
      end

      it 'excludes disallowed SAs' do
        disallowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when no restrictions are enabled' do
      let(:checker) { described_class.new(target_group: root_group) }

      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
        stub_feature_flags(
          allow_subgroups_to_create_service_accounts: false,
          allow_projects_to_create_service_accounts: false
        )
      end

      it 'returns unfiltered relation' do
        disallowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: other_group)

        users = User.all
        result = checker.filter_users(users)

        expect(result).to include(disallowed_sa)
      end
    end

    context 'when composite identity restriction is enabled', :saas do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'excludes subgroup SAs without composite_identity_enforced (subgroup hierarchy restriction always applies)' do
        subgroup_sa_no_composite = create(:user, :service_account, composite_identity_enforced: false,
          provisioned_by_group: subgroup)

        result = checker.filter_users(User.all)

        expect(result).not_to include(subgroup_sa_no_composite)
      end

      it 'includes SAs from allowed hierarchy with composite_identity_enforced' do
        allowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: root_group)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_sa)
      end

      it 'excludes SAs from unrelated groups with composite_identity_enforced' do
        disallowed_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when only subgroup hierarchy restriction is enabled' do
      let(:checker) { described_class.new(target_group: subgroup) }

      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      it 'includes top-level SAs (no subgroup hierarchy restriction for top-level)' do
        allowed_sa = create(:user, :service_account, provisioned_by_group: root_group)
        allowed_unrelated_top_level_sa = create(:user, :service_account, provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_sa, allowed_unrelated_top_level_sa)
      end

      it 'includes SAs from allowed subgroup hierarchy' do
        allowed_subgroup_sa = create(:user, :service_account, provisioned_by_group: subgroup)

        result = checker.filter_users(User.all)

        expect(result).to include(allowed_subgroup_sa)
      end

      it 'excludes SAs from unrelated subgroup hierarchies' do
        unrelated_subgroup = create(:group, parent: other_group)
        disallowed_unrelated_subgroup_sa = create(:user, :service_account, provisioned_by_group: unrelated_subgroup)

        result = checker.filter_users(User.all)

        expect(result).not_to include(disallowed_unrelated_subgroup_sa)
      end
    end

    context 'when both target_group and target_project are nil' do
      let(:checker) { described_class.new }

      it 'returns unfiltered relation as a safe no-op default' do
        user = create(:user)

        users = User.all
        result = checker.filter_users(users)

        expect(result).to include(user)
      end
    end

    context 'when filtering from a subgroup', :saas do
      let(:checker) { described_class.new(target_group: subgroup) }

      it 'includes SAs from target group and ancestors' do
        root_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        subgroup_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)

        result = checker.filter_users(User.all)

        expect(result).to include(root_sa, subgroup_sa)
      end

      it 'excludes SAs from descendants' do
        nested_sa = create(:user, :service_account, composite_identity_enforced: true,
          provisioned_by_group: nested_subgroup)

        result = checker.filter_users(User.all)

        expect(result).not_to include(nested_sa)
      end

      it 'excludes SAs from unrelated groups' do
        other_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)

        result = checker.filter_users(User.all)

        expect(result).not_to include(other_sa)
      end
    end

    context 'when respecting original relation scope' do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'respects the original relation scope' do
        active_user = create(:user)
        blocked_user = create(:user, :blocked)

        result = checker.filter_users(User.active)

        expect(result).to include(active_user)
        expect(result).not_to include(blocked_user)
      end
    end

    context 'with instance-level SAs' do
      let(:checker) { described_class.new(target_group: root_group) }

      it 'includes instance-level SAs regardless of restrictions' do
        instance_sa = create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)

        result = checker.filter_users(User.all)

        expect(result).to include(instance_sa)
      end
    end

    context 'with deeply nested subgroup hierarchy' do
      let_it_be(:deeply_nested) { create(:group, parent: nested_subgroup) }
      let(:checker) { described_class.new(target_group: deeply_nested) }

      it 'includes SAs from all ancestors' do
        root_sa = create(:user, :service_account, provisioned_by_group: root_group)
        nested_sa = create(:user, :service_account, provisioned_by_group: nested_subgroup)
        deeply_nested_sa = create(:user, :service_account, provisioned_by_group: deeply_nested)

        result = checker.filter_users(User.all)

        expect(result).to include(root_sa, nested_sa, deeply_nested_sa)
      end

      it 'excludes SAs from sibling groups' do
        sibling = create(:group, parent: nested_subgroup)
        sibling_sa = create(:user, :service_account, provisioned_by_group: sibling)

        result = checker.filter_users(User.all)

        expect(result).not_to include(sibling_sa)
      end
    end

    context 'with project-provisioned service accounts' do
      let_it_be(:project_in_root) { create(:project, namespace: root_group) }
      let_it_be(:other_project) { create(:project, namespace: other_group) }

      before do
        stub_feature_flags(allow_projects_to_create_service_accounts: true)
      end

      context 'when filtering for a group' do
        let(:checker) { described_class.new(target_group: root_group) }

        it 'excludes all project-provisioned SAs' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end

          result = checker.filter_users(User.all)

          expect(result).not_to include(project_sa)
        end
      end

      context 'when filtering for a project' do
        let(:checker) { described_class.new(target_project: project_in_root) }

        it 'includes the project-provisioned SA from the same project' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end

          result = checker.filter_users(User.all)

          expect(result).to include(project_sa)
        end

        it 'excludes project-provisioned SAs from other projects' do
          other_project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: other_project.id)
          end

          result = checker.filter_users(User.all)

          expect(result).not_to include(other_project_sa)
        end

        it 'includes regular users' do
          regular_user = create(:user)

          result = checker.filter_users(User.all)

          expect(result).to include(regular_user)
        end
      end

      context 'when filtering for a different project' do
        let(:checker) { described_class.new(target_project: other_project) }

        it 'excludes project-provisioned SAs from other projects' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end

          result = checker.filter_users(User.all)

          expect(result).not_to include(project_sa)
        end

        it 'includes group-provisioned SAs' do
          group_sa = create(:user, :service_account, provisioned_by_group: root_group)

          result = checker.filter_users(User.all)

          expect(result).to include(group_sa)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(allow_projects_to_create_service_accounts: false)
        end

        let(:checker) { described_class.new(target_group: root_group) }

        it 'still filters project-provisioned SAs (FF only controls SA creation, not invite restrictions)' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end

          result = checker.filter_users(User.all)

          expect(result).not_to include(project_sa)
        end
      end

      context 'when filtering for a project in personal namespace' do
        let_it_be(:personal_namespace) { create(:namespace) }
        let_it_be(:project_in_personal_namespace) { create(:project, namespace: personal_namespace) }
        let(:checker) { described_class.new(target_project: project_in_personal_namespace) }

        before do
          stub_feature_flags(allow_projects_to_create_service_accounts: true)
        end

        it 'includes the project-provisioned SA from the same project' do
          project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_personal_namespace.id)
          end

          result = checker.filter_users(User.all)

          expect(result).to include(project_sa)
        end

        it 'excludes project-provisioned SAs from other projects' do
          other_project_sa = create(:user, :service_account).tap do |user|
            user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
          end

          result = checker.filter_users(User.all)

          expect(result).not_to include(other_project_sa)
        end

        it 'includes instance-level SAs' do
          instance_sa = create(:user, :service_account, provisioned_by_group: nil)

          result = checker.filter_users(User.all)

          expect(result).to include(instance_sa)
        end

        it 'includes group-provisioned SAs' do
          group_sa = create(:user, :service_account, provisioned_by_group: root_group)

          result = checker.filter_users(User.all)

          expect(result).to include(group_sa)
        end

        it 'includes regular users' do
          regular_user = create(:user)

          result = checker.filter_users(User.all)

          expect(result).to include(regular_user)
        end
      end
    end
  end

  context 'when composite identity feature flag behavior', :saas do
    let(:checker) { described_class.new(target_group: target_group) }
    let(:target_group) { root_group }

    subject(:eligible) { checker.eligible?(sa) }

    context 'when service_accounts_invite_restrictions is disabled' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }

      it { is_expected.to be true }
    end

    context 'when top-level SA has composite_identity_enforced but no subgroup hierarchy restriction' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }
      let(:target_group) { subgroup }

      it { is_expected.to be true }
    end
  end

  context 'with combined restrictions', :saas do
    let(:checker) { described_class.new(target_group: target_group) }
    let(:target_group) { root_group }

    subject(:eligible) { checker.eligible?(sa) }

    context 'when both composite identity and subgroup restrictions apply' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup) }

      it { is_expected.to be false }
    end

    context 'when only composite identity restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group) }

      it { is_expected.to be false }
    end

    context 'when only subgroup hierarchy restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: subgroup) }

      it { is_expected.to be false }
    end

    context 'when neither restriction applies' do
      let(:sa) { create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: root_group) }
      let(:target_group) { subgroup }

      it { is_expected.to be true }
    end

    context 'when project provisioning and composite identity restrictions apply' do
      let_it_be(:project_in_root) { create(:project, namespace: root_group) }
      let(:sa) do
        create(:user, :service_account, composite_identity_enforced: true).tap do |user|
          user.user_detail.update!(provisioned_by_project_id: project_in_root.id)
        end
      end

      before do
        stub_feature_flags(allow_projects_to_create_service_accounts: true)
      end

      context 'when inviting to origin project' do
        let(:checker) { described_class.new(target_project: project_in_root) }

        it { is_expected.to be true }
      end

      context 'when inviting to group' do
        it { is_expected.to be false }
      end
    end
  end
end
