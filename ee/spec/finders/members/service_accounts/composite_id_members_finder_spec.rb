# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ServiceAccounts::CompositeIdMembersFinder, feature_category: :system_access do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:other_group) { create(:group) }

  let(:group) { root_group }
  let(:finder) { described_class.new(group) }

  describe '#execute' do
    subject(:execute) { finder.execute(members_relation) }

    let(:members_relation) { Member.all }

    context 'with group and project members' do
      let_it_be(:mixed_group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: mixed_group) }

      let_it_be(:regular_user) { create(:user) }
      let_it_be(:group_member) { create(:group_member, :developer, user: regular_user, source: mixed_group) }
      let_it_be(:project_member) { create(:project_member, :developer, user: regular_user, source: project) }

      let_it_be(:allowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: mixed_group)
      end

      let_it_be(:allowed_sa_group_member) { create(:group_member, :developer, user: allowed_sa, source: mixed_group) }
      let_it_be(:allowed_sa_project_member) { create(:project_member, :developer, user: allowed_sa, source: project) }

      let_it_be(:disallowed_sa) do
        create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: other_group)
      end

      let_it_be(:disallowed_sa_group_member) do
        create(:group_member, :developer, user: disallowed_sa, source: mixed_group)
      end

      let_it_be(:disallowed_sa_project_member) do
        create(:project_member, :developer, user: disallowed_sa, source: project)
      end

      let(:group) { mixed_group }

      it 'includes members with allowed users' do
        expect(execute).to include(
          group_member,
          project_member,
          allowed_sa_group_member,
          allowed_sa_project_member
        )
      end

      it 'excludes members with disallowed users' do
        expect(execute).not_to include(disallowed_sa_group_member, disallowed_sa_project_member)
      end
    end

    context 'when members_relation is scoped' do
      let_it_be(:scoped_group) { create(:group) }
      let_it_be(:active_user) { create(:user) }
      let_it_be(:blocked_user) { create(:user, :blocked) }

      let_it_be(:active_member) { create(:group_member, :developer, user: active_user, source: scoped_group) }
      let_it_be(:blocked_member) { create(:group_member, :developer, user: blocked_user, source: scoped_group) }

      let(:group) { scoped_group }
      let(:members_relation) { Member.where(source: scoped_group).joins(:user).merge(User.active) }

      it 'respects the original relation scope' do
        expect(execute).to include(active_member)
        expect(execute).not_to include(blocked_member)
      end
    end

    context 'when members_relation is empty' do
      let(:members_relation) { Member.none }

      it 'returns an empty relation' do
        expect(execute).to be_empty
      end
    end
  end
end
