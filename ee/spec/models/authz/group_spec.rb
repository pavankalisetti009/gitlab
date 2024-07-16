# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Group, feature_category: :system_access do
  subject(:group_authorization) { scope ? described_class.new(user, scope: scope) : described_class.new(user) }

  let(:scope) { nil }

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:child_group) { create(:group, parent: group) }

  let_it_be(:admin_runners_role) { create(:member_role, :guest, :admin_runners, namespace: root_group) }
  let_it_be(:admin_vulnerability_role) { create(:member_role, :guest, :admin_vulnerability, namespace: root_group) }
  let_it_be(:read_dependency_role) { create(:member_role, :guest, :read_dependency, namespace: root_group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { group_authorization.permitted }

    context 'when authorized for different permissions at different levels in the group hierarchy' do
      let_it_be(:memberships) do
        [
          [admin_runners_role, root_group],
          [admin_vulnerability_role, group],
          [read_dependency_role, child_group]
        ]
      end

      before_all do
        memberships.each do |(role, group)|
          create(:group_member, :guest, member_role: role, user: user, source: group)
        end
      end

      it { is_expected.to include(root_group.id => match_array([:admin_runners])) }

      it do
        permissions = [:admin_runners, :admin_vulnerability, :read_vulnerability]
        is_expected.to include(group.id => match_array(permissions))
      end

      it do
        is_expected.to include(child_group.id => match_array([
          :admin_runners,
          :admin_vulnerability,
          :read_dependency,
          :read_vulnerability
        ]))
      end
    end
  end

  describe "#permitted_to" do
    subject(:permitted_to) { group_authorization.permitted_to(custom_ability) }

    let(:custom_ability) { :admin_runners }

    it { is_expected.to be_empty }

    context 'when authorized for a project' do
      let_it_be(:project) { create(:project, group: group) }

      before_all do
        create(:project_member, :guest, member_role: admin_runners_role, user: user, source: project)
      end

      it { is_expected.to be_empty }
    end

    context 'when authorized for root group' do
      before_all do
        create(:group_member, :guest, member_role: admin_runners_role, user: user, source: root_group)
      end

      it { is_expected.to match_array([root_group, group, child_group]) }
    end

    context 'when authorized for group' do
      before_all do
        create(:group_member, :guest, member_role: admin_runners_role, user: user, source: group)
      end

      it { is_expected.to match_array([group, child_group]) }
    end

    context 'when authorized for child group' do
      before_all do
        create(:group_member, :guest, member_role: admin_runners_role, user: user, source: child_group)
      end

      it { is_expected.to match_array([child_group]) }
    end

    context 'when authorized for different permissions at different levels in the group hierarchy' do
      let_it_be(:memberships) do
        [
          [admin_runners_role, root_group],
          [admin_vulnerability_role, group],
          [read_dependency_role, child_group]
        ]
      end

      before_all do
        memberships.each do |(role, group)|
          create(:group_member, :guest, member_role: role, user: user, source: group)
        end
      end

      describe ":admin_runners" do
        let(:custom_ability) { :admin_runners }

        it { is_expected.to match_array([root_group, group, child_group]) }

        context 'when overriding the default scope' do
          let(:scope) { ::Group.where(id: [group.id]) }

          it { is_expected.to match_array([group]) }
        end
      end

      describe ":admin_vulnerability" do
        let(:custom_ability) { :admin_vulnerability }

        it { is_expected.to match_array([group, child_group]) }
      end

      describe ":read_dependency" do
        let(:custom_ability) { :read_dependency }

        it { is_expected.to match_array([child_group]) }

        context 'when overriding the default scope' do
          let(:scope) { ::Group.where(id: [group.id]) }

          it { is_expected.to be_empty }
        end
      end
    end
  end
end
