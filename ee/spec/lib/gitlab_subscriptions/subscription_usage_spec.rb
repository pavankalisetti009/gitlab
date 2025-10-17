# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsage, feature_category: :consumables_cost_management do
  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  describe '#start_date' do
    subject(:start_date) { subscription_usage.start_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

        it 'returns the start date' do
          expect(start_date).to be("2025-10-01")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end

      context 'when the client response is missing startDate' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: nil } } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the start date' do
        expect(start_date).to be("2025-10-01")
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { start_date }.not_to raise_error
        end
      end
    end
  end

  describe '#end_date' do
    subject(:end_date) { subscription_usage.end_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

        it 'returns the end date' do
          expect(end_date).to be("2025-10-31")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end

      context 'when the client response is missing endDate' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: nil } } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the end date' do
        expect(end_date).to be("2025-10-31")
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { end_date }.not_to raise_error
        end
      end
    end
  end

  describe '#purchase_credits_path' do
    subject(:purchase_credits_path) { subscription_usage.purchase_credits_path }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: "/mock/path" } } }

        it 'returns the end date' do
          expect(purchase_credits_path).to be("/mock/path")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when the client response is missing purchaseCreditsPath' do
        let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: nil } } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: "/mock/path" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the end date' do
        expect(purchase_credits_path).to be("/mock/path")
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { purchase_credits_path }.not_to raise_error
        end
      end
    end
  end

  describe '#last_updated' do
    subject(:last_updated) { subscription_usage.last_updated }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { lastUpdated: "2025-10-01T16:19:59Z" } } }

        it 'returns the last updated time' do
          expect(last_updated).to be("2025-10-01T16:19:59Z")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(last_updated).to be_nil
        end
      end

      context 'when the client response is missing lastUpdated' do
        let(:client_response) { { success: true, subscriptionUsage: { lastUpdated: nil } } }

        it 'returns nil' do
          expect(last_updated).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { lastUpdated: "2025-10-01T16:19:59Z" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the last updated time' do
        expect(last_updated).to be("2025-10-01T16:19:59Z")
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { last_updated }.not_to raise_error
        end
      end
    end
  end

  describe '#pool_usage' do
    subject(:pool_usage) { subscription_usage.pool_usage }

    before do
      allow(subscription_usage_client).to receive(:get_pool_usage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            poolUsage: {
              totalCredits: 1000,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns a PoolUsage struct with correct data' do
          expect(pool_usage).to be_a(GitlabSubscriptions::SubscriptionUsage::PoolUsage)
          expect(pool_usage).to have_attributes(
            total_credits: 1000,
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )

          expect(pool_usage.daily_usage).to be_a(Array)
          expect(pool_usage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(pool_usage.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(pool_usage).to be_nil
        end
      end

      context 'when the client response is missing poolUsage data' do
        let(:client_response) do
          {
            success: true,
            poolUsage: nil
          }
        end

        it 'returns a PoolUsage struct with no values' do
          expect(pool_usage).to be_a(GitlabSubscriptions::SubscriptionUsage::PoolUsage)
          expect(pool_usage).to have_attributes(
            total_credits: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          poolUsage: {
            totalCredits: 2000,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a PoolUsage struct with correct data' do
        expect(pool_usage).to be_a(GitlabSubscriptions::SubscriptionUsage::PoolUsage)
        expect(pool_usage).to have_attributes(
          total_credits: 2000,
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )

        expect(pool_usage.daily_usage).to be_a(Array)
        expect(pool_usage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(pool_usage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { pool_usage }.not_to raise_error
        end
      end
    end
  end

  describe '#overage' do
    subject(:overage) { subscription_usage.overage }

    before do
      allow(subscription_usage_client).to receive(:get_overage_usage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            overage: {
              isAllowed: true,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns an Overage struct with correct data' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: true,
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )

          expect(overage.daily_usage).to be_a(Array)
          expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(overage.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(overage).to be_nil
        end
      end

      context 'when the client response is missing overage data' do
        let(:client_response) do
          {
            success: true,
            overage: nil
          }
        end

        it 'returns an Overage struct with no values' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          overage: {
            isAllowed: true,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns an Overage struct with correct data' do
        expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
        expect(overage).to have_attributes(
          is_allowed: true,
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )

        expect(overage.daily_usage).to be_a(Array)
        expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(overage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end

      context 'when License.current is nil' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it 'handles nil license gracefully' do
          expect { overage }.not_to raise_error
        end
      end
    end
  end

  describe '#users_usage' do
    subject(:users_usage) { subscription_usage.users_usage }

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      it 'includes namespace users in the users field' do
        expect(users_usage.users).to match_array(users.first(2))
      end

      it 'sets declarative_policy_subject to SubscriptionUsage' do
        expect(users_usage.declarative_policy_subject).to eq(subscription_usage)
      end

      context 'when namespace is nil' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client
          )
        end

        it 'raises an error when trying to get users' do
          expect { users_usage.users }.to raise_error(NoMethodError)
        end
      end

      context 'when namespace has no users' do
        let(:no_members_namespace) { create(:group) }
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            subscription_usage_client: subscription_usage_client,
            namespace: no_members_namespace
          )
        end

        it 'returns empty collection' do
          expect(users_usage.users).to be_empty
        end
      end

      context 'with user stats' do
        before do
          allow(subscription_usage_client).to receive(:get_users_usage_stats).and_return(client_response)
        end

        context 'when the client returns a successful response' do
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

          it 'returns the expected data' do
            expect(users_usage).to have_attributes(
              total_users_using_credits: 3,
              total_users_using_pool: 2,
              total_users_using_overage: 1
            )

            expect(users_usage.daily_usage).to be_a(Array)
            expect(users_usage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
            expect(users_usage.daily_usage.first).to have_attributes(
              date: '2025-10-01',
              credits_used: 321,
              declarative_policy_subject: subscription_usage
            )
          end
        end

        context 'when the client returns an unsuccessful response' do
          let(:client_response) { { success: false } }

          it 'returns nil' do
            expect(users_usage).to have_attributes(
              total_users_using_credits: nil,
              total_users_using_pool: nil,
              total_users_using_overage: nil,
              daily_usage: []
            )
          end
        end

        context 'when the client response is missing the data' do
          let(:client_response) { { success: true, usersUsage: nil } }

          it 'returns nil' do
            expect(users_usage).to have_attributes(
              total_users_using_credits: nil,
              total_users_using_pool: nil,
              total_users_using_overage: nil,
              daily_usage: []
            )
          end
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      it 'includes all users in the users field' do
        expect(users_usage.users).to match_array(users)
      end

      it 'sets declarative_policy_subject to self' do
        expect(users_usage.declarative_policy_subject).to eq(subscription_usage)
      end
    end

    context 'when subscription_target is unknown' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :unknown,
          subscription_usage_client: subscription_usage_client
        )
      end

      it 'returns nil for unknown subscription target' do
        expect(users_usage.users).to be_nil
      end
    end
  end
end
