# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::MembershipEligibilityChecker, feature_category: :system_access do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:other_group) { create(:group) }

  describe '#eligible?' do
    let(:checker) { described_class.new(target_namespace) }
    let(:target_namespace) { root_group }

    subject { checker.eligible?(sa) }

    context 'with non-service account user' do
      let(:sa) { create(:user) }

      it { is_expected.to be true }
    end

    context 'with nil user' do
      let(:sa) { nil }

      it { is_expected.to be true }
    end

    context 'with nil target_namespace' do
      let(:target_namespace) { nil }
      let(:sa) { create(:user, :service_account) }

      it { is_expected.to be true }
    end

    context 'with composite identity restrictions', :saas do
      context 'when SA is from origin group' do
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        let(:target_namespace) { root_group }

        it { is_expected.to be true }
      end

      context 'when SA is from subgroup of origin' do
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
        end

        let(:target_namespace) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is from unrelated group' do
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
        end

        let(:target_namespace) { root_group }

        it { is_expected.to be false }
      end

      context 'when SA is from unrelated subgroup' do
        let_it_be(:other_subgroup) { create(:group, parent: other_group) }
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_subgroup)
        end

        let(:target_namespace) { root_group }

        it { is_expected.to be false }
      end

      context 'when SA is from parent of origin group' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:child_origin_group) { create(:group, parent: parent_group) }
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: child_origin_group)
        end

        let(:target_namespace) { parent_group }

        it { is_expected.to be false }
      end

      context 'when SA does not have composite_identity_enforced' do
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: other_group)
        end

        let(:target_namespace) { root_group }

        it { is_expected.to be true }
      end

      context 'when SA is instance-level (no provisioned_by_group)' do
        let_it_be(:sa) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)
        end

        let(:target_namespace) { root_group }

        it { is_expected.to be true }
      end
    end

    context 'with subgroup hierarchy restrictions' do
      context 'when SA is created in subgroup and invited to same subgroup' do
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_namespace) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in subgroup and invited to descendant' do
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_namespace) { nested_subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in subgroup and invited to parent' do
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_namespace) { root_group }

        it { is_expected.to be false }
      end

      context 'when SA is created in root group' do
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: root_group) }
        let(:target_namespace) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in unrelated root group (top-level)' do
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: other_group) }
        let(:target_namespace) { subgroup }

        it { is_expected.to be true }
      end

      context 'when SA is created in unrelated subgroup' do
        let_it_be(:unrelated_subgroup) { create(:group, parent: other_group) }
        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: unrelated_subgroup) }
        let(:target_namespace) { subgroup }

        it { is_expected.to be false }
      end

      context 'when allow_subgroups_to_create_service_accounts is disabled' do
        before do
          stub_feature_flags(allow_subgroups_to_create_service_accounts: false)
        end

        let_it_be(:sa) { create(:user, :service_account, provisioned_by_group: subgroup) }
        let(:target_namespace) { root_group }

        it 'does not apply subgroup hierarchy restrictions' do
          expect(checker.eligible?(sa)).to be true
        end
      end
    end
  end

  describe '#filter_users' do
    let(:checker) { described_class.new(target_namespace) }
    let(:target_namespace) { root_group }

    context 'with mixed user types and both restrictions enabled', :saas do
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:allowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:disallowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      let_it_be(:instance_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)
      end

      it 'includes regular users' do
        result = checker.filter_users(User.all)
        expect(result).to include(regular_user)
      end

      it 'includes allowed SAs' do
        result = checker.filter_users(User.all)
        expect(result).to include(allowed_sa, instance_sa)
      end

      it 'excludes disallowed SAs' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when no restrictions are enabled' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
        stub_feature_flags(allow_subgroups_to_create_service_accounts: false)
      end

      let_it_be(:disallowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      it 'returns unfiltered relation' do
        users = User.all
        result = checker.filter_users(users)
        expect(result).to eq(users)
      end
    end

    context 'when only composite identity restriction is enabled', :saas do
      before do
        stub_feature_flags(allow_subgroups_to_create_service_accounts: false)
      end

      let_it_be(:allowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:disallowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      let_it_be(:subgroup_sa_no_composite) do
        create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: subgroup)
      end

      it 'includes SAs without composite_identity_enforced' do
        result = checker.filter_users(User.all)
        expect(result).to include(subgroup_sa_no_composite)
      end

      it 'includes SAs from allowed hierarchy with composite_identity_enforced' do
        result = checker.filter_users(User.all)
        expect(result).to include(allowed_sa)
      end

      it 'excludes SAs from unrelated groups with composite_identity_enforced' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(disallowed_sa)
      end
    end

    context 'when only subgroup hierarchy restriction is enabled' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:target_namespace) { subgroup }

      let_it_be(:allowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:allowed_subgroup_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)
      end

      let_it_be(:allowed_unrelated_top_level_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      let_it_be(:disallowed_unrelated_subgroup_sa) do
        unrelated_subgroup = create(:group, parent: other_group)
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: unrelated_subgroup)
      end

      it 'includes top-level SAs (no subgroup hierarchy restriction for top-level)' do
        result = checker.filter_users(User.all)
        expect(result).to include(allowed_sa, allowed_unrelated_top_level_sa)
      end

      it 'includes SAs from allowed subgroup hierarchy' do
        result = checker.filter_users(User.all)
        expect(result).to include(allowed_subgroup_sa)
      end

      it 'excludes SAs from unrelated subgroup hierarchies' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(disallowed_unrelated_subgroup_sa)
      end
    end

    context 'when target_namespace is nil' do
      let(:target_namespace) { nil }
      let_it_be(:user) { create(:user) }

      it 'returns unfiltered relation' do
        users = User.all
        result = checker.filter_users(users)
        expect(result).to eq(users)
      end
    end

    context 'when filtering from a subgroup', :saas do
      let(:target_namespace) { subgroup }

      let_it_be(:root_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:subgroup_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)
      end

      let_it_be(:nested_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nested_subgroup)
      end

      let_it_be(:other_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      it 'includes SAs from target group and ancestors' do
        result = checker.filter_users(User.all)
        expect(result).to include(root_sa, subgroup_sa)
      end

      it 'excludes SAs from descendants' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(nested_sa)
      end

      it 'excludes SAs from unrelated groups' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(other_sa)
      end
    end

    context 'when respecting original relation scope' do
      let_it_be(:active_user) { create(:user) }
      let_it_be(:blocked_user) { create(:user, :blocked) }

      it 'respects the original relation scope' do
        scoped_users = User.active
        result = checker.filter_users(scoped_users)
        expect(result).to include(active_user)
        expect(result).not_to include(blocked_user)
      end
    end

    context 'with instance-level SAs' do
      let_it_be(:instance_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)
      end

      it 'includes instance-level SAs regardless of restrictions' do
        result = checker.filter_users(User.all)
        expect(result).to include(instance_sa)
      end
    end

    context 'with deeply nested subgroup hierarchy' do
      let_it_be(:deeply_nested) { create(:group, parent: nested_subgroup) }
      let(:target_namespace) { deeply_nested }

      let_it_be(:root_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:nested_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nested_subgroup)
      end

      let_it_be(:deeply_nested_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: deeply_nested)
      end

      let_it_be(:sibling_sa) do
        sibling = create(:group, parent: nested_subgroup)
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: sibling)
      end

      it 'includes SAs from all ancestors' do
        result = checker.filter_users(User.all)
        expect(result).to include(root_sa, nested_sa, deeply_nested_sa)
      end

      it 'excludes SAs from sibling groups' do
        result = checker.filter_users(User.all)
        expect(result).not_to include(sibling_sa)
      end
    end
  end

  describe 'composite identity feature flag behavior', :saas do
    let_it_be(:sa) do
      create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
    end

    let(:checker) { described_class.new(target_namespace) }
    let(:target_namespace) { root_group }

    subject { checker.eligible?(sa) }

    context 'when service_accounts_invite_restrictions is disabled' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      it { is_expected.to be true }
    end

    context 'when top-level SA has composite_identity_enforced but no subgroup hierarchy restriction' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      let(:target_namespace) { subgroup }

      it { is_expected.to be true }
    end
  end

  describe 'combined restrictions', :saas do
    let(:checker) { described_class.new(target_namespace) }
    let(:target_namespace) { root_group }

    subject { checker.eligible?(sa) }

    context 'when both restrictions apply' do
      let_it_be(:sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)
      end

      it { is_expected.to be false }
    end

    context 'when only composite identity restriction applies' do
      let_it_be(:sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      it { is_expected.to be false }
    end

    context 'when only subgroup hierarchy restriction applies' do
      let_it_be(:sa) do
        create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: subgroup)
      end

      it { is_expected.to be false }
    end

    context 'when neither restriction applies' do
      let_it_be(:sa) do
        create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: root_group)
      end

      let(:target_namespace) { subgroup }

      it { is_expected.to be true }
    end
  end
end
