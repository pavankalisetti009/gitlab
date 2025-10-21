# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.subscriptionUsage', feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:root_group) { create(:group, owners: owner, maintainers: maintainer) }
  let_it_be(:subgroup) { create(:group, parent: root_group, owners: owner) }
  let_it_be(:project_namespace) { create(:project_namespace, owner: owner) }
  let_it_be(:user_namespace) { create(:user_namespace, owner: owner) }

  let(:error_message) do
    "The resource that you are attempting to access does not exist or you don't have permission to perform this action"
  end

  let(:user_arguments) { {} }
  let(:query_fields) do
    [
      :last_updated,
      :start_date,
      :end_date,
      :purchase_credits_path,
      query_graphql_field(:pool_usage, {}, [
        :total_credits,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ]),
      query_graphql_field(:overage, {}, [
        :is_allowed,
        :credits_used,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used])
      ]),
      query_graphql_field(:users_usage, {}, [
        :total_users_using_credits,
        :total_users_using_pool,
        :total_users_using_overage,
        query_graphql_field(:daily_usage, {}, [:date, :credits_used]),
        query_graphql_field(:users, user_arguments, [
          query_graphql_field(:nodes, {}, [
            :id,
            :name,
            :username,
            :avatar_url,
            query_graphql_field(:usage, {}, [:total_credits, :credits_used, :pool_credits_used, :overage_credits_used])
          ])
        ])
      ])
    ]
  end

  let(:query) do
    graphql_query_for(
      :subscription_usage,
      {
        namespace_path: namespace_path,
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month
      },
      query_fields
    )
  end

  shared_examples 'empty response' do
    it 'returns nil for subscription usage' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(:subscription_usage)).to be_nil
    end

    it 'returns an error message' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end
  end

  before do
    stub_feature_flags(usage_billing_dev: true)

    metadata = {
      success: true,
      subscriptionUsage: {
        startDate: "2025-10-01",
        endDate: "2025-10-31",
        lastUpdated: "2025-10-01T16:19:59Z",
        purchaseCreditsPath: '/mock/path'
      }
    }

    users_usage = User.all.map do |user|
      {
        userId: user.id,
        totalCredits: user.id,
        creditsUsed: user.id * 10,
        poolCreditsUsed: user.id * 100,
        overageCreditsUsed: user.id * 2
      }
    end

    get_users_usage_stats = {
      success: true,
      usersUsage: {
        totalUsersUsingCredits: 3,
        totalUsersUsingPool: 2,
        totalUsersUsingOverage: 1,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
      }
    }

    pool_usage = {
      success: true,
      poolUsage: {
        totalCredits: 1000,
        creditsUsed: 250,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 250 }]
      }
    }

    overage_usage = {
      success: true,
      overage: {
        isAllowed: true,
        creditsUsed: 150,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 150 }]
      }
    }

    allow_next_instance_of(Gitlab::SubscriptionPortal::SubscriptionUsageClient) do |client|
      allow(client).to receive_messages(
        get_metadata: metadata,
        get_pool_usage: pool_usage,
        get_overage_usage: overage_usage,
        get_usage_for_user_ids: { success: true, usersUsage: users_usage },
        get_users_usage_stats: get_users_usage_stats
      )
    end
  end

  context 'when in Self-Managed' do
    let(:namespace_path) { nil }

    context 'with admin user' do
      context 'when feature flag is enabled' do
        before do
          post_graphql(query, current_user: admin)
        end

        it 'returns subscription usage for instance' do
          expect(graphql_data_at(:subscription_usage, :lastUpdated)).to eq("2025-10-01T16:19:59Z")
          expect(graphql_data_at(:subscription_usage, :startDate)).to eq("2025-10-01")
          expect(graphql_data_at(:subscription_usage, :endDate)).to eq("2025-10-31")
          expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath)).to eq("/mock/path")

          expect(graphql_data_at(:subscription_usage, :poolUsage)).to eq({
            totalCredits: 1000,
            creditsUsed: 250,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 250 }]
          }.with_indifferent_access)

          expect(graphql_data_at(:subscription_usage, :overage)).to eq({
            isAllowed: true,
            creditsUsed: 150,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 150 }]
          }.with_indifferent_access)

          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingCredits)).to eq(3)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingPool)).to eq(2)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingOverage)).to eq(1)
          expect(graphql_data_at(:subscription_usage, :usersUsage, :dailyUsage))
              .to match_array([{ date: '2025-10-01', creditsUsed: 321 }.with_indifferent_access])

          expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array(
            User.all.map do |u|
              {
                id: u.to_global_id.to_s,
                name: u.name,
                username: u.username,
                avatarUrl: u.avatar_url,
                usage: {
                  totalCredits: u.id,
                  creditsUsed: u.id * 10,
                  poolCreditsUsed: u.id * 100,
                  overageCreditsUsed: u.id * 2
                }
              }.with_indifferent_access
            end
          )
        end

        context 'when filtering users by username' do
          let(:user_arguments) { { username: maintainer.username } }

          it 'returns user data for the specified user only' do
            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array([
              {
                id: maintainer.to_global_id.to_s,
                name: maintainer.name,
                username: maintainer.username,
                avatarUrl: maintainer.avatar_url,
                usage: {
                  totalCredits: maintainer.id,
                  creditsUsed: maintainer.id * 10,
                  poolCreditsUsed: maintainer.id * 100,
                  overageCreditsUsed: maintainer.id * 2
                }
              }.with_indifferent_access
            ])
          end
        end

        context 'when filtering non-existent username' do
          let(:user_arguments) { { username: 'non-existent' } }

          it 'returns empty for user data' do
            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
          end
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(usage_billing_dev: false)
        end

        include_examples 'empty response' do
          let(:current_user) { admin }
        end
      end
    end

    context 'with non-admin user' do
      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end
  end

  context 'when in GitLab.com' do
    context 'with root group' do
      let(:namespace_path) { root_group.full_path }

      context 'when user is group owner' do
        context 'when feature flag is enabled' do
          before do
            post_graphql(query, current_user: owner)
          end

          it 'returns subscription usage for the group' do
            expect(graphql_data_at(:subscription_usage, :lastUpdated)).to eq("2025-10-01T16:19:59Z")
            expect(graphql_data_at(:subscription_usage, :startDate)).to eq("2025-10-01")
            expect(graphql_data_at(:subscription_usage, :endDate)).to eq("2025-10-31")
            expect(graphql_data_at(:subscription_usage, :purchaseCreditsPath)).to eq("/mock/path")

            expect(graphql_data_at(:subscription_usage, :poolUsage)).to eq({
              totalCredits: 1000,
              creditsUsed: 250,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 250 }]
            }.with_indifferent_access)

            expect(graphql_data_at(:subscription_usage, :overage)).to eq({
              isAllowed: true,
              creditsUsed: 150,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 150 }]
            }.with_indifferent_access)

            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingCredits)).to eq(3)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingPool)).to eq(2)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :totalUsersUsingOverage)).to eq(1)
            expect(graphql_data_at(:subscription_usage, :usersUsage, :dailyUsage))
              .to match_array([{ date: '2025-10-01', creditsUsed: 321 }.with_indifferent_access])

            expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array(
              root_group.users.map do |u|
                {
                  id: u.to_global_id.to_s,
                  name: u.name,
                  username: u.username,
                  avatarUrl: u.avatar_url,
                  usage: {
                    totalCredits: u.id,
                    creditsUsed: u.id * 10,
                    poolCreditsUsed: u.id * 100,
                    overageCreditsUsed: u.id * 2
                  }
                }.with_indifferent_access
              end
            )
          end

          context 'when filtering users by username' do
            let(:user_arguments) { { username: maintainer.username } }

            it 'returns user data for the specified user only' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to match_array([
                {
                  id: maintainer.to_global_id.to_s,
                  name: maintainer.name,
                  username: maintainer.username,
                  avatarUrl: maintainer.avatar_url,
                  usage: {
                    totalCredits: maintainer.id,
                    creditsUsed: maintainer.id * 10,
                    poolCreditsUsed: maintainer.id * 100,
                    overageCreditsUsed: maintainer.id * 2
                  }
                }.with_indifferent_access
              ])
            end
          end

          context 'when filtering a username that is not a group member' do
            let(:user_arguments) { { username: admin.username } }

            it 'returns empty for user data' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
            end
          end

          context 'when filtering non-existent username' do
            let(:user_arguments) { { username: 'non-existent' } }

            it 'returns empty for user data' do
              expect(graphql_data_at(:subscription_usage, :usersUsage, :users, :nodes)).to be_empty
            end
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(usage_billing_dev: false)
          end

          include_examples 'empty response' do
            let(:current_user) { owner }
          end
        end
      end

      context 'when user is not group owner' do
        include_examples 'empty response' do
          let(:current_user) { maintainer }
        end
      end
    end

    context 'with subgroup' do
      let(:namespace_path) { subgroup.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
        let(:error_message) { "Subscription usage can only be queried on a root namespace" }
      end
    end

    context 'with project namespace' do
      let(:namespace_path) { project_namespace.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end

    context 'with user namespace' do
      let(:namespace_path) { user_namespace.full_path }

      include_examples 'empty response' do
        let(:current_user) { owner }
      end
    end

    context 'with non-existent namespace' do
      let(:namespace_path) { 'non-existent-namespace' }

      include_examples 'empty response' do
        let(:current_user) { admin }
      end
    end
  end
end
