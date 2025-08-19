# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignments::MemberTransfers::CreateGroupSeatsWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_2) { create(:user) }
  let_it_be(:user_3) { create(:user) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  it_behaves_like 'an idempotent worker' do
    let_it_be(:group) { create(:group) }

    before do
      create(:group_member, group: group, user: user)
    end

    let(:job_args) { [group.id] }
  end

  describe '#perform' do
    context 'when the group is nil' do
      it 'does nothing' do
        expect(worker).not_to receive(:create_missing_seat_assignments)

        worker.perform(non_existing_record_id)
      end
    end

    context 'with a root group' do
      let_it_be_with_refind(:group) { create(:group) }

      before do
        create(:gitlab_subscription_seat_assignment, user: user, namespace: group)
      end

      context 'when group namespace has missing seats' do
        before do
          create(:group_member, group: group, user: user)
          create(:group_member, group: group, user: user_2)
          create(:group_member, group: group, user: user_3)
        end

        it 'creates seat assignments for the missing users' do
          worker.perform(group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
          ).to include(user_2.id, user_3.id)
        end

        it 'creates seat assignments for all members' do
          worker.perform(group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
          ).to match_array([user.id, user_2.id, user_3.id])
        end
      end

      context 'when a group namespace does not have missing seat assignments' do
        before do
          create(:group_member, group: group, user: user)
          create(:group_member, group: group, user: user_2)
          create(:group_member, group: group, user: user_3)
          create(:gitlab_subscription_seat_assignment, :active, user: user_2, namespace: group)
          create(:gitlab_subscription_seat_assignment, :active, user: user_3, namespace: group)
        end

        it 'does not create seat assignments' do
          expect do
            worker.perform(group.id)
          end.not_to change { GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id) }
        end
      end

      context 'when a root group has a project with members' do
        let_it_be(:project) { create(:project, namespace: group) }

        before do
          create(:group_member, group: group, user: user)
          create(:project_member, project: project, user: user_2)
          create(:project_member, project: project, user: user_3)
        end

        it 'creates seat assignments for the project members' do
          worker.perform(group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
          ).to include(user_2.id, user_3.id)
        end
      end

      context 'when a group has a parent root group' do
        let_it_be_with_refind(:transferred_group) { create(:group, parent: group) }
        let_it_be(:user_4) { create(:user) }

        before do
          create(:group_member, group: group, user: user_4)
          create(:group_member, group: transferred_group, user: user_2)
          create(:group_member, group: transferred_group, user: user_3)
        end

        it 'creates seat assignments in the root group for the members of the group being passed' do
          worker.perform(transferred_group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
          ).to match_array([user.id, user_2.id, user_3.id])
        end

        it 'does not create seats for members of the root group if a child group is passed' do
          worker.perform(transferred_group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
          ).not_to include(user_4.id)
        end

        it 'does not assign seats to the child group' do
          worker.perform(transferred_group.id)

          expect(
            GitlabSubscriptions::SeatAssignment.by_namespace(transferred_group)
          ).to be_empty
        end
      end

      context 'with nested hierarchy' do
        let_it_be(:child_group_a) { create(:group, parent: group) }
        let_it_be(:child_group_b) { create(:group, parent: group) }
        let_it_be(:child_group_c) { create(:group, parent: child_group_a) }
        let_it_be(:user_4) { create(:user) }

        before do
          create(:group_member, group: group, user: user)
          create(:group_member, group: child_group_a, user: user_2)
          create(:group_member, group: child_group_b, user: user_3)
          create(:group_member, group: child_group_c, user: user_4)
        end

        context 'when a leaf group is passed' do
          it 'creates seat assignments in the root group only for the members of the leaf group' do
            worker.perform(child_group_c.id)

            expect(
              GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
            ).to match_array([user.id, user_4.id])
          end
        end

        context 'when a subhierarchy is passed' do
          it 'creates seat assignments in the root group only for members of the subhierarchy' do
            worker.perform(child_group_a.id)

            expect(
              GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
            ).to match_array([user.id, user_2.id, user_4.id])
          end
        end

        context 'when a sibling group is passed' do
          it 'creates seat assignments in the root group only for the members of sibling' do
            worker.perform(child_group_b.id)

            expect(
              GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
            ).to match_array([user.id, user_3.id])
          end
        end

        context 'when the root group is passed' do
          it 'creates seat assignments in the root group for all members of the hierarchy' do
            worker.perform(group.id)

            expect(
              GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
            ).to match_array([user.id, user_2.id, user_3.id, user_4.id])
          end
        end
      end
    end
  end
end
