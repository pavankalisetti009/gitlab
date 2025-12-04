# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ServiceAccounts::CompositeIdUsersFinder, feature_category: :system_access do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:other_group) { create(:group) }

  let(:group) { root_group }
  let(:finder) { described_class.new(group) }

  describe '#execute' do
    subject(:execute) { finder.execute(users_relation) }

    let(:users_relation) { User.all }

    context 'with all user types' do
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:instance_wide_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: nil)
      end

      let_it_be(:root_group_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: root_group)
      end

      let_it_be(:subgroup_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: subgroup)
      end

      let_it_be(:other_group_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      let_it_be(:sa_without_composite_identity) do
        create(:user, :service_account, composite_identity_enforced: false, provisioned_by_group: other_group)
      end

      it 'includes regular users, instance-wide SAs, SAs not enforced, and SAs from target group' do
        expect(execute).to include(regular_user, instance_wide_sa, root_group_sa, sa_without_composite_identity)
      end

      it 'excludes SAs from descendant and unrelated groups' do
        expect(execute).not_to include(subgroup_sa, other_group_sa)
      end

      context 'when filtering from a subgroup' do
        let(:group) { subgroup }

        it 'includes SAs from target group and ancestors' do
          expect(execute).to include(root_group_sa, subgroup_sa)
        end

        it 'excludes SAs from unrelated groups' do
          expect(execute).not_to include(other_group_sa)
        end
      end
    end

    context 'when users_relation is scoped' do
      let_it_be(:blocked_user) { create(:user, :blocked) }
      let_it_be(:active_user) { create(:user) }

      let(:users_relation) { User.active }

      it 'respects the original relation scope' do
        expect(execute).to include(active_user)
        expect(execute).not_to include(blocked_user)
      end
    end

    context 'when users_relation is empty' do
      let(:users_relation) { User.none }

      it 'returns an empty relation' do
        expect(execute).to be_empty
      end
    end
  end
end
