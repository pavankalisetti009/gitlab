# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPreference do
  let_it_be(:user) { create(:user) }

  let(:user_preference) { create(:user_preference, user: user) }

  shared_context 'with multiple user add-on assignments' do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let_it_be(:groups) { create_list(:group_with_plan, 2, plan: :ultimate_plan) }

    let!(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, namespace: groups.second, add_on: duo_pro_add_on)
      ]
    end

    let!(:user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end
  end

  shared_examples 'updates roadmap_epics_state' do |state|
    it 'saves roadmap_epics_state in user_preference' do
      user_preference.update!(roadmap_epics_state: state)

      expect(user_preference.reload.roadmap_epics_state).to eq(state)
    end
  end

  describe 'associations' do
    it 'belongs to default_add_on_assignment optionally' do
      is_expected.to belong_to(:default_duo_add_on_assignment)
                       .class_name('GitlabSubscriptions::UserAddOnAssignment')
                       .optional
    end
  end

  describe 'roadmap_epics_state' do
    context 'when set to open epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:opened]
    end

    context 'when set to closed epics' do
      it_behaves_like 'updates roadmap_epics_state', Epic.available_states[:closed]
    end

    context 'when reset to all epics' do
      it_behaves_like 'updates roadmap_epics_state', nil
    end
  end

  describe '#eligible_duo_add_on_assignments', :saas do
    include_context 'with multiple user add-on assignments'

    let!(:non_eligible_user_assignments) do
      non_eligible_add_on = [
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: nil),
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first)
      ]

      non_eligible_add_on.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:eligible_user_assignments) { user_assignments }

    it 'only retrieves eligible user assignments with disctinct namespaces' do
      expect(user_preference.eligible_duo_add_on_assignments).to match_array(eligible_user_assignments)
    end
  end

  describe '#distinct_eligible_duo_add_on_assignments', :saas do
    include_context 'with multiple user add-on assignments'

    let!(:non_eligible_user_assignments) do
      non_eligible_add_on = [
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: nil),
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.second),
        create(:gitlab_subscription_add_on_purchase, namespace: groups.first, add_on: duo_pro_add_on)
      ]

      non_eligible_add_on.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:expected_eligible_namespaces) { user_assignments.map(&:namespace) }

    it 'only retrieves eligible user assignments' do
      actual_eligible_namespaces = user_preference.distinct_eligible_duo_add_on_assignments.map(&:namespace)

      expect(actual_eligible_namespaces).to match_array(expected_eligible_namespaces)
      expect(actual_eligible_namespaces.count).to eq(2)
    end
  end

  describe 'default_duo_add_on_assignment_id', :saas do
    let_it_be(:groups) do
      create_list(:group_with_plan, 2, plan: :ultimate_plan)
    end

    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    let!(:add_on_purchases) do
      [
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: groups.first),
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: groups.second),
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups.first)
      ]
    end

    let!(:user_assignments) do
      add_on_purchases.map do |add_on|
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end
    end

    let(:first_assignment_id) { user_preference.distinct_eligible_duo_add_on_assignments.to_a.first.id }
    let(:second_assignment_id) { user_preference.distinct_eligible_duo_add_on_assignments.to_a.second.id }

    context 'when default_duo_add_on_assignment_id has not changed?' do
      it 'does call #check_seat_for_default_duo_namespace' do
        expect(user_preference).not_to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.valid?
      end
    end

    context 'when default_duo_add_on_assignment_id has changed?' do
      it 'calls #check_seat_for_default_duo_namespace' do
        expect(user_preference).to receive(:check_seat_for_default_duo_assigment).and_call_original

        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.valid?
      end
    end

    context 'when a correct value is assigned' do
      it 'saves the value' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        expect(user_preference.default_duo_add_on_assignment_id).to eql(first_assignment_id)
      end
    end

    context 'when the seat gets destroyed' do
      it 'nullifies default duo_add_on_assignment_id' do
        user_preference.default_duo_add_on_assignment_id = first_assignment_id
        user_preference.save!

        user_assignments.first.destroy!
        user_preference.reload

        expect(user_preference.default_duo_add_on_assignment_id).to be_nil
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to assignment id with namespace attached' do
      it 'does not add any errors' do
        [first_assignment_id, second_assignment_id].each do |seat_id|
          user_preference.default_duo_add_on_assignment_id = seat_id
          user_preference.valid?

          expect(user_preference.errors[:default_duo_add_on_assignment_id]).to be_empty
        end
      end
    end

    context 'when default_duo_add_on_assignment_id is changed to non_existing_id' do
      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = non_existing_record_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{non_existing_record_id}")
      end
    end

    context 'when the assigment is not associated with a namespace' do
      let(:add_on_without_namespace) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: nil) }
      let(:user_assignment_id) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_without_namespace, user: user).id
      end

      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = user_assignment_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{user_assignment_id}")
      end
    end

    context 'when the assigment is not for a duo add on' do
      let(:non_duo_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: groups.first) }
      let(:user_assignment_id) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: non_duo_add_on, user: user).id
      end

      it 'does add an errors' do
        user_preference.default_duo_add_on_assignment_id = user_assignment_id
        user_preference.valid?

        expect(user_preference.errors[:default_duo_add_on_assignment_id])
          .to include("No Duo seat assignments with namespace found with ID #{user_assignment_id}")
      end
    end
  end

  describe 'no_eligible_duo_add_on_assignments?', :saas do
    context 'when there are multiple eligible duo add-on assignments' do
      include_context 'with multiple user add-on assignments'

      it 'returns false' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_falsey
      end
    end

    context 'when there is one eligible duo add-on assignment' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      let_it_be(:add_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
      end

      let!(:user_assignments) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
      end

      it 'returns false' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_falsey
      end
    end

    context 'when there are no eligible duo add-on assignments' do
      it 'returns true' do
        expect(user_preference.no_eligible_duo_add_on_assignments?).to be_truthy
      end
    end
  end

  describe '#get_default_duo_namespace', :saas do
    context 'when there are multiple eligible duo add-on assignments' do
      include_context 'with multiple user add-on assignments'

      context 'when default_duo_add_on_assignment is present' do
        let(:assignment) { user_assignments.second }
        let(:assignment_namespace) { groups.second }

        before do
          user_preference.update!(default_duo_add_on_assignment: assignment)
        end

        it 'returns the namespace from the default assignment' do
          expect(user_preference.get_default_duo_namespace).to eq(assignment_namespace)
        end
      end

      context 'when default_duo_add_on_assignment is not present' do
        it 'returns nil' do
          expect(user_preference.get_default_duo_namespace).to be_nil
        end
      end
    end

    context 'when there is only single assigning namespace' do
      let_it_be(:group) do
        create(:group_with_plan, plan: :ultimate_plan)
      end

      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
      end

      let!(:user_assignment) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      context 'when default_duo_add_on_assignment is not present' do
        context 'with a single eligible duo add-on assignment' do
          it 'returns the namespace from the single eligible assignment' do
            expect(user_preference.get_default_duo_namespace).to eq(group)
          end
        end

        context 'with multiple add-on assignments from the same namespace' do
          let_it_be(:second_add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group)
          end

          let!(:second_user_assignment) do
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: second_add_on_purchase, user: user)
          end

          it 'returns the namespace from the single eligible assignment' do
            expect(user_preference.get_default_duo_namespace).to eq(group)
          end
        end
      end

      context 'when default_duo_add_on_assignment is present' do
        before do
          user_preference.update!(default_duo_add_on_assignment: user_assignment)
        end

        it 'returns the namespace from the default assignment' do
          expect(user_preference.get_default_duo_namespace).to eq(group)
        end
      end
    end

    context 'when there are no eligible duo add-on assignments' do
      it 'returns nil' do
        expect(user_preference.get_default_duo_namespace).to be_nil
      end
    end
  end
end
