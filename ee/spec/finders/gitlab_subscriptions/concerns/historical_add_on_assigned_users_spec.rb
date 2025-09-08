# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Concerns::HistoricalAddOnAssignedUsers, :click_house, feature_category: :value_stream_management do
  describe '#historical_add_on_assigned_users' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: namespace)
    end

    before do
      allow(Gitlab::ClickHouse).to receive_messages(
        globally_enabled_for_analytics?: true,
        configured?: true
      )
    end

    subject(:assigned_users) do
      GitlabSubscriptions::AddOnAssignedUsersFinder.new(
        user,
        namespace,
        **finder_params
      ).historical_add_on_assigned_users
    end

    context 'when ClickHouse is not configured' do
      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
      end

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: 3.weeks.ago.to_date,
          before: nil
        }
      end

      it 'raises an error' do
        expect do
          assigned_users
        end.to raise_error(ClickHouse::Errors::DisabledError,
          /ClickHouse is not enabled: Failed to fetch historical add-on assignments/)
      end
    end

    context 'with only start_date specified' do
      let(:start_date) { 3.weeks.ago.to_date }
      let_it_be(:member) { create(:user, developer_of: namespace) }
      let_it_be(:other_member) { create(:user, developer_of: namespace) }
      let_it_be(:included_inactive_member) { create(:user, developer_of: namespace) }
      let_it_be(:excluded_inactive_member) { create(:user, developer_of: namespace) }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: start_date,
          before: nil
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: member.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil }
        ])

        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: other_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 4.weeks.ago,
            revoked_at: nil }
        ])

        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: included_inactive_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 4.weeks.ago,
            revoked_at: 1.week.ago }
        ])

        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: excluded_inactive_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 5.weeks.ago,
            revoked_at: 4.weeks.ago }
        ])
      end

      it 'finds both users that has active addon assignment' do
        expect(assigned_users).to contain_exactly(member, other_member, included_inactive_member)
      end
    end

    context 'with only end_date specified' do
      let(:end_date) { 1.week.ago.to_date }
      let_it_be(:member) { create(:user, developer_of: namespace) }
      let_it_be(:other_member) { create(:user, developer_of: namespace) }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: nil,
          before: end_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: member.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 30.days.ago,
            revoked_at: nil }
        ])

        # Outside the data range and is_expected to NOT be included
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: other_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 1.day.ago,
            revoked_at: nil }
        ])
      end

      it 'finds users asssigned to addon before end date' do
        expect(assigned_users).to contain_exactly(member)
      end
    end

    context 'with exact namespace path matching' do
      let_it_be(:parent_namespace) { create(:group, path: 'parent-group') }
      let_it_be(:child_namespace) { create(:group, path: 'child-group', parent: parent_namespace) }
      let_it_be(:similar_namespace) { create(:group, path: 'parent-group-similar') }

      let_it_be(:parent_member) { create(:user, developer_of: parent_namespace) }
      let_it_be(:child_member) { create(:user, developer_of: child_namespace) }
      let_it_be(:similar_member) { create(:user, developer_of: similar_namespace) }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: 3.weeks.ago.to_date,
          before: 1.week.ago.to_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          # Assignment for parent namespace
          { assignment_id: 1,
            namespace_path: parent_namespace.root_ancestor.traversal_path,
            user_id: parent_member.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil },
          # Assignment for child namespace
          { assignment_id: 2,
            namespace_path: child_namespace.root_ancestor.traversal_path,
            user_id: child_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil },
          # Assignment for similar namespace
          { assignment_id: 3,
            namespace_path: similar_namespace.root_ancestor.traversal_path,
            user_id: similar_member.id,
            purchase_id: 203,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil }
        ])
      end

      subject(:assigned_users) do
        GitlabSubscriptions::AddOnAssignedUsersFinder.new(
          user,
          parent_namespace,
          **finder_params
        ).historical_add_on_assigned_users
      end

      it 'includes users from the parent and child namespaces' do
        expect(assigned_users).to contain_exactly(parent_member, child_member)
      end
    end

    context 'with no namespace specified' do
      let_it_be(:org_namespace) { create(:group) }
      let_it_be(:main_member) { create(:user, developer_of: org_namespace) }
      let_it_be(:root_member) { create(:user, developer_of: org_namespace) }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: 3.weeks.ago.to_date,
          before: 1.week.ago.to_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: org_namespace.root_ancestor.traversal_path,
            user_id: root_member.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil },
          { assignment_id: 2,
            namespace_path: '0/',
            user_id: main_member.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil }
        ])
      end

      subject(:assigned_users) do
        GitlabSubscriptions::AddOnAssignedUsersFinder.new(
          user,
          nil,
          **finder_params
        ).historical_add_on_assigned_users
      end

      it 'includes users for self-managed instances when namespace is not specified' do
        expect(assigned_users).to contain_exactly(main_member)
      end
    end

    context 'with various date boundary conditions' do
      using RSpec::Parameterized::TableSyntax

      let(:test_start_date) { 20.days.ago.to_date }
      let(:test_end_date) { 10.days.ago.to_date }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: test_start_date,
          before: test_end_date
        }
      end

      let_it_be(:user) { create(:user, developer_of: namespace) }

      let(:before_start) { (test_start_date - 5.days).to_s }
      let(:on_start) { test_start_date.to_s }
      let(:during_range) { (test_start_date + 5.days).to_s }
      let(:during_range_late) { (test_start_date + 8.days).to_s }
      let(:on_end) { test_end_date.to_s }
      let(:after_end) { (test_end_date + 5.days).to_s }

      where(:case_name, :assigned_at, :revoked_at, :expected_result) do
        'Assigned before start date with no revocation'     | :before_start | nil              | true
        'Assigned exactly on start date'                    | :on_start     | nil              | true
        'Assigned during date range'                        | :during_range | nil              | true
        'Assigned exactly on end date'                      | :on_end       | nil              | true
        'Assigned after end date'                           | :after_end    | nil              | false
        'Revoked before start date'                         | :before_start | :before_start    | false
        'Revoked exactly on start date'                     | :before_start | :on_start        | true
        'Revoked during date range'                         | :before_start | :during_range    | true
        'Revoked exactly on end date'                       | :before_start | :on_end          | true
        'Revoked after end date'                            | :before_start | :after_end       | true
        'Assigned before, revoked during date range'        | :before_start | :during_range    | true
        'Assigned during, revoked during date range'        | :during_range | :during_range_late | true
      end

      with_them do
        before do
          actual_assigned_at = assigned_at.is_a?(Symbol) ? send(assigned_at) : assigned_at
          actual_revoked_at = revoked_at.is_a?(Symbol) ? send(revoked_at) : revoked_at

          clickhouse_fixture(:user_add_on_assignments_history, [
            { assignment_id: 100,
              namespace_path: namespace.root_ancestor.traversal_path,
              user_id: user.id,
              purchase_id: 500,
              add_on_name: 'code_suggestions',
              assigned_at: actual_assigned_at,
              revoked_at: actual_revoked_at }
          ])
        end

        it "correctly filters the user" do
          expect(assigned_users.include?(user)).to eq expected_result
        end
      end
    end

    context 'with historical data and multiple users' do
      let_it_be(:member_without_duo_pro) { create(:user, developer_of: namespace) }
      let(:start_date) { 3.weeks.ago.to_date }
      let(:end_date) { 1.week.ago.to_date }
      let_it_be(:another_member_with_duo_pro) { create(:user, developer_of: namespace) }

      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: start_date,
          before: end_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: another_member_with_duo_pro.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 10.days.ago,
            revoked_at: nil },
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: another_member_with_duo_pro.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 20.days.ago,
            revoked_at: 5.days.ago },
          { assignment_id: 3,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: member_without_duo_pro.id,
            purchase_id: 203,
            add_on_name: 'code_suggestions',
            assigned_at: 13.days.ago,
            revoked_at: 9.days.ago },
          { assignment_id: 4,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: create(:user).id,
            purchase_id: 203,
            add_on_name: 'code_suggestions',
            assigned_at: 25.days.ago,
            revoked_at: 30.days.ago }
        ])
      end

      it 'includes historical assignments from the specified date range' do
        expect(assigned_users).to match_array([another_member_with_duo_pro, member_without_duo_pro])
      end
    end

    context 'when namespace is nil' do
      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: 1.week.ago.to_date,
          before: Time.now.to_date
        }
      end

      let_it_be(:test_user) { create(:user) }
      let_it_be(:other_user) { create(:user) }

      subject(:assigned_users) do
        GitlabSubscriptions::AddOnAssignedUsersFinder.new(
          user,
          nil,
          **finder_params
        ).historical_add_on_assigned_users
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: '0/',
            user_id: test_user.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 3.days.ago,
            revoked_at: nil },
          { assignment_id: 2,
            namespace_path: '1/',
            user_id: other_user.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 3.days.ago,
            revoked_at: nil }
        ])
      end

      it 'returns users with namespace exactly matching 0/' do
        expect(assigned_users).to contain_exactly(test_user)
      end
    end

    context 'when after date is after before date' do
      let(:finder_params) do
        {
          add_on_name: :code_suggestions,
          after: 1.day.ago.to_date,
          before: 1.week.ago.to_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: user.id,
            purchase_id: 201,
            add_on_name: 'code_suggestions',
            assigned_at: 3.days.ago,
            revoked_at: nil }
        ])
      end

      it 'returns empty result when date range is invalid' do
        expect(assigned_users).to be_empty
      end
    end

    context 'when add_on_name filtering' do
      let_it_be(:test_user) { create(:user) }
      let_it_be(:test_user2) { create(:user) }
      let(:finder_params) do
        {
          add_on_name: :duo_pro,
          after: 1.week.ago.to_date,
          before: Time.now.to_date
        }
      end

      before do
        clickhouse_fixture(:user_add_on_assignments_history, [
          { assignment_id: 1,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: test_user.id,
            purchase_id: 201,
            add_on_name: 'duo_pro',
            assigned_at: 3.days.ago,
            revoked_at: nil },
          { assignment_id: 2,
            namespace_path: namespace.root_ancestor.traversal_path,
            user_id: test_user2.id,
            purchase_id: 202,
            add_on_name: 'code_suggestions',
            assigned_at: 3.days.ago,
            revoked_at: nil }
        ])
      end

      it 'filters by exact add_on_name match' do
        expect(assigned_users).to contain_exactly(test_user)
      end
    end
  end
end
