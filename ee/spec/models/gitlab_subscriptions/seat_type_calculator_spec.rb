# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatTypeCalculator,
  feature_category: :seat_cost_management do
  using RSpec::Parameterized::TableSyntax

  describe 'validations', :saas do
    context 'with nil user' do
      let(:user) { nil }
      let(:namespace) { create(:group) }

      it 'raises an error' do
        expect { described_class.new(user, namespace).execute }.to raise_error(
          ArgumentError, 'User must be present'
        )
      end
    end

    context 'with nil namespace' do
      let(:user) { create(:user) }
      let(:namespace) { nil }

      it 'raises an error' do
        expect { described_class.new(user, namespace).execute }.to raise_error(
          ArgumentError, 'Namespace must be present'
        )
      end
    end
  end

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:seat_type) { described_class.new(user, namespace).execute }

    context 'when on saas', :saas do
      context 'with a namespace on a free plan' do
        before do
          create(:gitlab_subscription, :free, namespace: namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :base
            ::Gitlab::Access::PLANNER    | :base
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: namespace) }

          before do
            create(:group_member, group: namespace, user: user, access_level: ::Gitlab::Access::GUEST)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end
      end

      context 'with a namespace on a premium plan' do
        before do
          create(:gitlab_subscription, :premium, namespace: namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :base
            ::Gitlab::Access::PLANNER    | :base
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: namespace) }

          before do
            create(:group_member, :minimal_access, group: namespace, user: user)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end

        context "when a user's max role is minimal access" do
          let(:user) { create(:user) }

          before do
            create(:group_member, :minimal_access, group: namespace, user: user)
          end

          it 'returns free seat type' do
            expect(seat_type).to eq(:free)
          end
        end
      end

      context 'with a namespace on an ultimate plan' do
        before do
          create(:gitlab_subscription, :ultimate, namespace: namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :free
            ::Gitlab::Access::PLANNER    | :plan
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: namespace) }

          before do
            create(:group_member, group: namespace, user: user, access_level: ::Gitlab::Access::GUEST)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end

        context "when a user's max role is minimal access" do
          let(:user) { create(:user) }

          before do
            create(:group_member, :minimal_access, group: namespace, user: user)
          end

          it 'returns free seat type' do
            expect(seat_type).to eq(:free)
          end
        end
      end

      context 'with a bot user' do
        let(:user) { create(:user, :bot) }

        before do
          create(:group_member, group: namespace, user: user)
        end

        it 'returns system seat type' do
          expect(seat_type).to eq(:system)
        end
      end
    end

    context 'when on self-managed' do
      it 'returns nil' do
        expect(seat_type).to be_nil
      end
    end
  end
end
