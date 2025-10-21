# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsUsage::UserUsage, feature_category: :consumables_cost_management do
  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }
  let(:subscription_usage) { instance_double(GitlabSubscriptions::SubscriptionUsage) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let(:client_response) do
    {
      success: true,
      usersUsage: {
        totalUsersUsingCredits: 3,
        totalUsersUsingPool: 2,
        totalUsersUsingOverage: 1,
        dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }]
      }
    }
  end

  subject(:user_usage) { described_class.new(subscription_usage: subscription_usage) }

  before do
    allow(subscription_usage).to receive(:subscription_usage_client).and_return(subscription_usage_client)
  end

  describe "#daily_usage" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        {
          success: true,
          usersUsage: { dailyUsage: [{ date: '2025-10-01', creditsUsed: 321 }] }
        }
      end

      it 'returns the correct daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(user_usage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 321,
          declarative_policy_subject: subscription_usage
        )
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns an empty array for daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage).to be_empty
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns an empty array for daily usage' do
        expect(user_usage.daily_usage).to be_a(Array)
        expect(user_usage.daily_usage).to be_empty
      end
    end
  end

  describe "#total_users_using_credits" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingCredits: 3 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_credits).to eq(3)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_credits).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_credits).to be_nil
      end
    end
  end

  describe "#total_users_using_pool" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingPool: 2 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_pool).to eq(2)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_pool).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_pool).to be_nil
      end
    end
  end

  describe "#total_users_using_overage" do
    before do
      allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) { { success: true, usersUsage: { totalUsersUsingOverage: 1 } } }

      it 'returns the correct data' do
        expect(user_usage.total_users_using_overage).to eq(1)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(user_usage.total_users_using_overage).to be_nil
      end
    end

    context 'when the client response is missing the data' do
      let(:client_response) { { success: true, usersUsage: nil } }

      it 'returns nil' do
        expect(user_usage.total_users_using_overage).to be_nil
      end
    end
  end

  describe "#users" do
    context 'when subscription_target is :namespace' do
      before do
        allow(subscription_usage).to receive_messages(
          subscription_target: :namespace,
          namespace: group
        )
      end

      it 'includes namespace users in the users field' do
        expect(user_usage.users).to match_array(users.first(2))
      end

      context 'when filtering by username' do
        it 'returns the user matching the username' do
          first_user = users.first
          expect(user_usage.users(username: first_user.username)).to match_array([first_user])
        end

        it 'returns nil when the user does not exist' do
          expect(user_usage.users(username: 'non-existent')).to be_empty
        end

        it 'returns nil when user is not a member of the group' do
          expect(user_usage.users(username: users.third.username)).to be_empty
        end
      end

      context 'when namespace is nil' do
        before do
          allow(subscription_usage).to receive(:namespace).and_return(nil)
        end

        it 'raises an error when trying to get users' do
          expect { user_usage.users }.to raise_error(NoMethodError)
        end
      end

      context 'when namespace has no users' do
        let(:no_members_namespace) { create(:group) }

        before do
          allow(subscription_usage).to receive(:namespace).and_return(no_members_namespace)
        end

        it 'returns empty collection' do
          expect(user_usage.users).to be_empty
        end
      end
    end

    context 'when subscription_target is :instance' do
      before do
        allow(subscription_usage).to receive(:subscription_target).and_return(:instance)
      end

      it 'includes all users in the users field' do
        expect(user_usage.users).to match_array(users)
      end

      context 'when filtering by username' do
        it 'returns the user matching the username' do
          first_user = users.first
          expect(user_usage.users(username: first_user.username)).to match_array([first_user])
        end

        it 'returns nil when the user does not exist' do
          expect(user_usage.users(username: 'non-existent')).to be_empty
        end
      end
    end

    context 'when subscription_target is unknown' do
      before do
        allow(subscription_usage).to receive(:subscription_target).and_return(:unknown)
      end

      it 'returns nil for unknown subscription target' do
        expect(user_usage.users).to be_nil
      end
    end
  end

  describe "#declarative_policy_subject" do
    it 'sets declarative_policy_subject to SubscriptionUsage' do
      expect(user_usage.declarative_policy_subject).to eq(subscription_usage)
    end
  end
end
