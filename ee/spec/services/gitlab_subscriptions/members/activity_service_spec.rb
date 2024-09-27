# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::ActivityService, :clean_gitlab_redis_shared_state, feature_category: :seat_cost_management do
  include ExclusiveLeaseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  let(:lease_key) { "gitlab_subscriptions:members_activity_event:#{namespace.id}:#{user.id}" }
  let(:instance) { described_class.new(user, namespace) }

  describe '#execute' do
    subject(:execute) { instance.execute }

    describe 'with valid params', :freeze_time do
      it 'create a new seat assignment record' do
        expect do
          expect(execute).to be_success
        end.to change {
          GitlabSubscriptions::SeatAssignment.where(
            namespace: namespace, user: user, last_activity_on: Time.current
          ).count
        }
      end

      it 'updates the existing seat_assignment record' do
        seat_assignment = create(:gitlab_subscription_seat_assignment, namespace: namespace, user: user)

        expect do
          expect(execute).to be_success
        end.to change { seat_assignment.reload.last_activity_on }
          .from(nil).to(Time.current)
      end

      context 'with project belonging to a group' do
        let(:namespace) { build(:project, :in_group) }

        it 'returns success' do
          expect do
            expect(execute).to be_success
          end.to change { GitlabSubscriptions::SeatAssignment.count }.by(1)
        end
      end

      it 'tries to obtain a lease' do
        ttl = (Time.current.end_of_day - Time.current).to_i
        expect_to_obtain_exclusive_lease(lease_key, timeout: ttl)

        expect(execute).to be_success
      end

      context 'when a lease cannot be obtained' do
        it 'returns success, without updating any record' do
          stub_exclusive_lease_taken(lease_key)

          expect(instance).not_to receive(:seat_assignment)

          expect(execute).to be_success
        end
      end
    end

    shared_examples 'returns an error' do
      it do
        response = execute

        expect(response).to be_error
        expect(response.message).to eq('Invalid params')
      end
    end

    context 'with no namespace' do
      let(:namespace) { nil }

      it_behaves_like 'returns an error'
    end

    context 'with namespace not belonging to a group' do
      let(:namespace) { create(:user_namespace) }

      it_behaves_like 'returns an error'
    end

    context 'with no user' do
      let(:user) { nil }

      it_behaves_like 'returns an error'
    end
  end
end
