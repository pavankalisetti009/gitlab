# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatTypeCalculator,
  feature_category: :seat_cost_management do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:seat_type) { described_class.execute(user, namespace) }

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
        before_all do
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
        let_it_be(:user) { create(:user, :bot) }

        before_all do
          create(:group_member, group: namespace, user: user)
        end

        it 'returns system seat type' do
          expect(seat_type).to eq(:system)
        end
      end

      context 'with user ID' do
        subject(:seat_type) { described_class.execute(user.id, namespace) }

        before_all do
          create(:group_member, group: namespace, user: user)
        end

        it 'returns base seat type' do
          expect(seat_type).to eq(:base)
        end
      end
    end

    context 'when on Self-Managed' do
      it 'returns nil' do
        expect(seat_type).to be_nil
      end
    end
  end

  describe '#bulk_execute' do
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:seat_types) { described_class.bulk_execute([user1, user2], namespace) }

    context 'when on Self-Managed' do
      it 'returns an empty hash' do
        expect(seat_types).to eq({})
      end
    end

    context 'when on saas', :saas do
      before do
        create(:gitlab_subscription, :ultimate, namespace: namespace)
      end

      context 'with memberships' do
        before_all do
          namespace.add_guest(user1)
          namespace.add_developer(user2)
        end

        it 'returns seat types for multiple users' do
          expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
        end

        context 'with active record scope' do
          subject(:seat_types) { described_class.bulk_execute(User.all, namespace) }

          it 'returns seat types for multiple users' do
            expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
          end
        end

        context 'with user IDs' do
          subject(:seat_types) { described_class.bulk_execute([user1.id, user2.id], namespace) }

          it 'returns seat types for multiple users' do
            expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
          end
        end
      end

      context 'with memberships in other groups' do
        subject(:seat_types) { described_class.bulk_execute([user1], namespace) }

        before_all do
          namespace.add_guest(user1)

          group = create(:group)
          group.add_maintainer(user1)
        end

        it 'only considers specified namespace' do
          expect(seat_types).to eq({ user1.id => :free })
        end
      end

      context 'without memberships' do
        it 'returns nil seat types' do
          expect(seat_types).to eq({ user1.id => nil, user2.id => nil })
        end
      end

      context 'with array with mixed values' do
        subject(:seat_types) { described_class.bulk_execute([user1, nil, user2], namespace) }

        it 'filters out nil values' do
          expect(seat_types).to eq({ user1.id => nil, user2.id => nil })
        end
      end
    end
  end
end
