# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignments::MemberTransfers::CreateProjectSeatsWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:user_2) { create(:user) }
  let_it_be(:user_3) { create(:user) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  it_behaves_like 'an idempotent worker' do
    let_it_be(:project) { create(:project) }

    before do
      create(:project_member, project: project, user: user)
    end

    let(:job_args) { [project.id] }
  end

  describe '#perform' do
    it 'does nothing when there is no project' do
      expect(worker).not_to receive(:create_missing_seat_assignments)

      worker.perform(non_existing_record_id)
    end

    context 'when the project root namespace is a user namespace' do
      let_it_be(:project) { create(:project, namespace: user.namespace) }

      before do
        create(:project_member, project: project, user: user_2)
        create(:project_member, project: project, user: user_3)
        create(:gitlab_subscription_seat_assignment, user: user, namespace: project.namespace)
      end

      it 'creates seat assignments in the user namespace only for members of the project' do
        worker.perform(project.id)

        expect(
          GitlabSubscriptions::SeatAssignment.by_namespace(project.namespace).pluck(:user_id)
        ).to match_array([user.id, user_2.id, user_3.id])
      end

      context 'when a user namespace does not have missing seat assignments' do
        before do
          create(:gitlab_subscription_seat_assignment, user: user_2, namespace: project.namespace)
          create(:gitlab_subscription_seat_assignment, user: user_3, namespace: project.namespace)
        end

        it 'does not create duplicates if seat assignments are already reconciled' do
          expect do
            worker.perform(project.id)
          end.not_to change { GitlabSubscriptions::SeatAssignment.by_namespace(project.namespace).count }
        end
      end
    end

    context 'when the project root namespace is a group' do
      let_it_be_with_refind(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        create(:group_member, group: group, user: user)
        create(:project_member, project: project, user: user_2)
        create(:project_member, project: project, user: user_3)
      end

      it 'creates seat assignments in the root group only for the members of the project' do
        worker.perform(project.id)

        expect(
          GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
        ).to match_array([user_2.id, user_3.id])
      end

      context 'when the root group namespace already has seats for the project members' do
        before do
          create(:gitlab_subscription_seat_assignment, user: user_2, namespace: group)
          create(:gitlab_subscription_seat_assignment, user: user_3, namespace: group)
        end

        it 'does not create duplicate seats' do
          expect do
            worker.perform(project.id)
          end.not_to change { GitlabSubscriptions::SeatAssignment.by_namespace(group).count }
        end
      end
    end

    context 'when the project belongs to a subgroup' do
      let_it_be_with_refind(:group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, namespace: child_group) }

      before do
        create(:group_member, group: group, user: user)
        create(:group_member, group: child_group, user: user_2)
        create(:project_member, project: project, user: user_3)
      end

      it 'creates seat assignments in the root group only for the members of the project' do
        worker.perform(project.id)

        expect(
          GitlabSubscriptions::SeatAssignment.by_namespace(group).pluck(:user_id)
        ).to match_array([user_3.id])
      end
    end
  end
end
