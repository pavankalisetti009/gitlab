# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Groups::TransferService, :aggregate_failures, feature_category: :organization do
  let_it_be(:old_organization) { create(:organization) }
  let_it_be(:new_organization) { create(:organization) }
  let_it_be(:user) { create(:user, organization: old_organization) }
  let_it_be_with_refind(:group) { create(:group, organization: old_organization) }

  let(:service) { described_class.new(group: group, new_organization: new_organization, current_user: user) }

  before_all do
    group.add_owner(user)
    new_organization.add_owner(user)
  end

  describe '#execute' do
    context 'when transfer is successful' do
      let_it_be_with_refind(:subgroup) { create(:group, parent: group, organization: old_organization) }
      let_it_be_with_refind(:project) { create(:project, namespace: group, organization: old_organization) }

      context 'for seat assignment transfers' do
        let_it_be_with_refind(:user1) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:user2) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:user3) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:seat_assignment1) do
          create(:gitlab_subscription_seat_assignment,
            namespace: group,
            user: user1,
            organization_id: old_organization.id)
        end

        let_it_be_with_refind(:seat_assignment2) do
          create(:gitlab_subscription_seat_assignment,
            namespace: group,
            user: user2,
            organization_id: old_organization.id)
        end

        let_it_be_with_refind(:seat_assignment3) do
          create(:gitlab_subscription_seat_assignment,
            namespace: group,
            user: user3,
            organization_id: old_organization.id)
        end

        before_all do
          group.add_maintainer(user1)
          group.add_developer(user2)
          group.add_guest(user3)
        end

        it 'updates organization_id for seat assignments' do
          service.execute

          expect(seat_assignment1.reload.organization_id).to eq(new_organization.id)
          expect(seat_assignment2.reload.organization_id).to eq(new_organization.id)
          expect(seat_assignment3.reload.organization_id).to eq(new_organization.id)
        end

        it 'only updates seat assignments for the transferring group' do
          other_group = create(:group, organization: old_organization)
          other_seat_assignment = create(:gitlab_subscription_seat_assignment,
            namespace: other_group,
            user: user1,
            organization_id: old_organization.id)

          service.execute

          expect(other_seat_assignment.reload.organization_id).to eq(old_organization.id)
        end

        context 'when batching updates' do
          let_it_be_with_refind(:seat_assignment4) do
            create(:gitlab_subscription_seat_assignment,
              namespace: group,
              user: create(:user, organization: old_organization),
              organization_id: old_organization.id)
          end

          let_it_be_with_refind(:seat_assignment5) do
            create(:gitlab_subscription_seat_assignment,
              namespace: group,
              user: create(:user, organization: old_organization),
              organization_id: old_organization.id)
          end

          it 'processes seat assignments in batches' do
            stub_const("Organizations::Concerns::OrganizationUpdater::ORGANIZATION_ID_UPDATE_BATCH_SIZE", 2)
            batch_count = 0

            allow(GitlabSubscriptions::SeatAssignment)
              .to receive(:each_batch).and_wrap_original do |method, **kwargs, &block|
              method.call(**kwargs) do |batch|
                batch_count += 1
                block.call(batch)
              end
            end

            service.execute

            # With 5 records and batch size of 2, we expect 3 batches
            expect(batch_count).to eq(3)
            expect(seat_assignment1.reload.organization_id).to eq(new_organization.id)
            expect(seat_assignment2.reload.organization_id).to eq(new_organization.id)
            expect(seat_assignment3.reload.organization_id).to eq(new_organization.id)
            expect(seat_assignment4.reload.organization_id).to eq(new_organization.id)
            expect(seat_assignment5.reload.organization_id).to eq(new_organization.id)
          end
        end
      end

      context 'for add-on purchase transfers' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
        let_it_be_with_refind(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase,
            :active,
            add_on: add_on,
            namespace: group,
            organization: old_organization)
        end

        let_it_be_with_refind(:add_on_purchase_2) do
          create(:gitlab_subscription_add_on_purchase,
            :active,
            add_on: create(:gitlab_subscription_add_on, :duo_enterprise),
            namespace: group,
            organization: old_organization)
        end

        it 'updates organization_id for all add-on purchases' do
          service.execute

          expect(add_on_purchase.reload.organization_id).to eq(new_organization.id)
          expect(add_on_purchase_2.reload.organization_id).to eq(new_organization.id)
        end
      end

      context 'for user add-on assignment transfers' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
        let_it_be_with_refind(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase,
            :active,
            add_on: add_on,
            namespace: group,
            organization: old_organization)
        end

        let_it_be_with_refind(:user1) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:user2) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:user3) { create(:user, organization: old_organization) }
        let_it_be_with_refind(:user_add_on_assignment1) do
          create(:gitlab_subscription_user_add_on_assignment,
            user: user1,
            add_on_purchase: add_on_purchase,
            organization_id: old_organization.id)
        end

        let_it_be_with_refind(:user_add_on_assignment2) do
          create(:gitlab_subscription_user_add_on_assignment,
            user: user2,
            add_on_purchase: add_on_purchase,
            organization_id: old_organization.id)
        end

        let_it_be_with_refind(:user_add_on_assignment3) do
          create(:gitlab_subscription_user_add_on_assignment,
            user: user3,
            add_on_purchase: add_on_purchase,
            organization_id: old_organization.id)
        end

        before_all do
          group.add_maintainer(user1)
          group.add_developer(user2)
          group.add_guest(user3)
        end

        it 'updates organization_id for user add-on assignments' do
          service.execute

          expect(user_add_on_assignment1.reload.organization_id).to eq(new_organization.id)
          expect(user_add_on_assignment2.reload.organization_id).to eq(new_organization.id)
          expect(user_add_on_assignment3.reload.organization_id).to eq(new_organization.id)
        end

        context 'when user add-on assignments belong to different add-on purchase' do
          let_it_be(:other_group) { create(:group, organization: old_organization) }
          let_it_be_with_refind(:other_add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase,
              :active,
              add_on: add_on,
              namespace: other_group,
              organization: old_organization)
          end

          let_it_be_with_refind(:other_assignment) do
            create(:gitlab_subscription_user_add_on_assignment,
              user: user1,
              add_on_purchase: other_add_on_purchase,
              organization_id: old_organization.id)
          end

          it 'does not update assignments for other add-on purchases' do
            service.execute

            expect(user_add_on_assignment1.reload.organization_id).to eq(new_organization.id)
            expect(other_assignment.reload.organization_id).to eq(old_organization.id)
          end
        end
      end
    end

    context 'when transfer fails' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
      let_it_be_with_refind(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase,
          :active,
          add_on: add_on,
          namespace: group,
          organization: old_organization)
      end

      let_it_be_with_refind(:user1) { create(:user, organization: old_organization) }
      let_it_be_with_refind(:seat_assignment) do
        create(:gitlab_subscription_seat_assignment,
          namespace: group,
          user: user1,
          organization_id: old_organization.id)
      end

      let_it_be_with_refind(:user_add_on_assignment) do
        create(:gitlab_subscription_user_add_on_assignment,
          user: user1,
          add_on_purchase: add_on_purchase,
          organization_id: old_organization.id)
      end

      before_all do
        group.add_maintainer(user1)
      end

      context 'when user transfer raises an exception' do
        let(:error_message) { 'User transfer failed' }

        before do
          allow_next_instance_of(Organizations::Users::TransferService) do |user_service|
            allow(user_service).to receive(:perform_transfer).and_raise(ActiveRecord::RecordNotUnique, error_message)
          end
        end

        it_behaves_like 'rolls back organization_id updates' do
          let(:records) { [add_on_purchase, seat_assignment, user_add_on_assignment] }
        end

        it 'returns error ServiceResponse' do
          result = service.execute

          expect(result).to be_a(ServiceResponse)
          expect(result).to be_error
          expect(result.message).to eq(error_message)
        end
      end
    end
  end
end
