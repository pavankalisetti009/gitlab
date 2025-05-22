# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignments::GroupLinks::CreateOrUpdateSeatsWorker, :saas, feature_category: :seat_cost_management do
  describe '.perform' do
    let_it_be(:group_a) { create(:group) }
    let_it_be_with_refind(:group_b) { create(:group) }
    let_it_be(:group_a_owner) { create(:user) }
    let_it_be(:group_b_owner) { create(:user) }

    subject(:worker) { described_class.new }

    before_all do
      group_a.add_owner(group_a_owner)
      group_b.add_owner(group_b_owner)
    end

    context 'when root group A is invited to root group B' do
      let_it_be_with_refind(:link) { create(:group_group_link, shared_with_group: group_a, shared_group: group_b) }

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { link.id }
      end

      it 'creates seat assignments in the shared group for each user in the invited group' do
        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id)
      end

      it "does nothing if it doesn't find the group link" do
        worker.perform(non_existing_record_id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).not_to include(group_a_owner.id)
      end

      it 'does nothing if a seat assignment already exists for the user' do
        ::GitlabSubscriptions::SeatAssignment.create!(
          namespace: group_b,
          user: group_a_owner,
          organization_id: group_b.organization_id
        )

        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id)
      end
    end

    context 'when root group A is invited to a subgroup within the root group B hierarchy' do
      let_it_be(:subgroup_b) { create(:group, parent: group_b) }
      let_it_be_with_refind(:link) { create(:group_group_link, shared_with_group: group_a, shared_group: subgroup_b) }

      it 'creates seat assignments for the shared group root ancestor' do
        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to include(group_a_owner.id)
      end
    end

    context 'when a subgroup is invited to another subgroup within the same hierarchy' do
      let_it_be(:subgroup_b1) { create(:group, parent: group_b) }
      let_it_be(:subgroup_b2) { create(:group, parent: group_b) }
      let_it_be_with_refind(:link) do
        create(:group_group_link, shared_with_group: subgroup_b1, shared_group: subgroup_b2)
      end

      before_all do
        subgroup_b1.add_developer(create(:user))
      end

      it 'does nothing' do
        worker.perform(link.id)

        expect(group_b.subscription_seat_assignments.map(&:user_id)).to be_empty
      end
    end
  end
end
