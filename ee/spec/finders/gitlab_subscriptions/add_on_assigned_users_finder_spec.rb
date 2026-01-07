# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnAssignedUsersFinder, feature_category: :seat_cost_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:subgroup) { create(:group, parent: namespace) }
    let_it_be(:another_subgroup) { create(:group, parent: namespace) }
    let_it_be(:project) { create(:project, group: another_subgroup) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let(:finder_params) { { add_on_name: :code_suggestions } }
    let(:after) { 2.weeks.ago.to_date }
    let(:before) { DateTime.now.to_date }

    subject(:assigned_users) do
      described_class.new(user, namespace, **finder_params).execute
    end

    context 'when selecting between historical and current data paths' do
      context 'when before & after are provided' do
        let(:finder_params) do
          { add_on_name: :code_suggestions, after: after, before: before }
        end

        it 'uses historical_add_on_assigned_users' do
          expect_next_instance_of(described_class) do |instance|
            expect(instance).to receive(:historical_add_on_assigned_users).and_return(User.none)
            expect(instance).not_to receive(:current_add_on_assigned_users)
          end

          assigned_users
        end
      end

      context 'when only after is provided' do
        let(:finder_params) do
          { add_on_name: :code_suggestions, after: after }
        end

        it 'uses historical_add_on_assigned_users' do
          expect_next_instance_of(described_class) do |instance|
            expect(instance).to receive(:historical_add_on_assigned_users).and_return(User.none)
            expect(instance).not_to receive(:current_add_on_assigned_users)
          end

          assigned_users
        end
      end

      context 'when only before is provided' do
        let(:finder_params) do
          { add_on_name: :code_suggestions, before: before }
        end

        it 'uses historical_add_on_assigned_users' do
          expect_next_instance_of(described_class) do |instance|
            expect(instance).to receive(:historical_add_on_assigned_users).and_return(User.none)
            expect(instance).not_to receive(:current_add_on_assigned_users)
          end

          assigned_users
        end
      end

      context 'when neither after nor before are provided' do
        let(:finder_params) do
          { add_on_name: :code_suggestions }
        end

        it 'uses current_add_on_assigned_users regardless of feature flag state' do
          expect_next_instance_of(described_class) do |instance|
            expect(instance).not_to receive(:historical_add_on_assigned_users)
            expect(instance).to receive(:current_add_on_assigned_users).and_return(User.none)
          end

          assigned_users
        end
      end
    end

    context 'with current data path (no before parameter)' do
      context 'without add_on_purchase' do
        it { is_expected.to be_empty }
      end

      context 'with expired add_on_purchase' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
        end

        let_it_be(:member_with_duo_pro) do
          create(:user, developer_of: namespace).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        it { is_expected.to be_empty }
      end

      context 'with active add_on_purchase' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: namespace)
        end

        let_it_be(:member_with_duo_pro) do
          create(:user, developer_of: namespace).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:subgroup_member_with_duo_pro) do
          create(:user, developer_of: subgroup).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:another_subgroup_member_with_duo_pro) do
          create(:user, developer_of: another_subgroup).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:project_member_with_duo_pro) do
          create(:user, developer_of: project).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:member_without_duo_pro) { create(:user, developer_of: namespace) }

        it 'returns all assigned users of a group' do
          expect(assigned_users).to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro,
            subgroup_member_with_duo_pro])
        end

        context 'with subgroup namespace' do
          let(:assigned_users) { described_class.new(user, subgroup, **finder_params).execute }

          it 'returns all subgroup members with assigned seat' do
            expect(assigned_users).to match_array([member_with_duo_pro, subgroup_member_with_duo_pro])
          end
        end

        context 'with project namespace' do
          let(:assigned_users) do
            described_class.new(user, project.project_namespace, **finder_params).execute
          end

          it 'returns all project members with assigned seat' do
            expect(assigned_users)
              .to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro,
                project_member_with_duo_pro])
          end
        end

        context 'with instance level add_on_purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, :self_managed, add_on: add_on)
          end

          it 'returns all assigned users of given group' do
            expect(assigned_users).to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro,
              subgroup_member_with_duo_pro])
          end
        end
      end
    end

    context 'with historical data path (with before parameter)' do
      let(:finder_params) do
        { add_on_name: :code_suggestions, after: after, before: before }
      end

      it 'delegates to the historical concern' do
        # This tests that the historical_add_on_assigned_users method from the concern is called
        # The actual implementation of historical_add_on_assigned_users would be tested
        # in the spec for Concerns::HistoricalAddOnAssignedUsers
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:historical_add_on_assigned_users).and_return(User.none)
        end

        expect(assigned_users).to eq(User.none)
      end
    end
  end
end
