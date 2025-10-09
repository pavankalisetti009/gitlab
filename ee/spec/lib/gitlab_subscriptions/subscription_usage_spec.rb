# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsage, feature_category: :consumables_cost_management do
  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }
  let(:start_date) { Date.current.beginning_of_month }
  let(:end_date) { Date.current.end_of_month }

  describe '#pool_usage' do
    subject(:pool_usage) { subscription_usage.pool_usage }

    before do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:get_subscription_pool_usage)
        .and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          namespace: group,
          start_date: start_date,
          end_date: end_date
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            poolUsage: {
              totalUnits: 1000,
              unitsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'calls the subscription portal client with correct parameters' do
          pool_usage

          expect(Gitlab::SubscriptionPortal::Client).to have_received(:get_subscription_pool_usage)
            .with(
              license_key: nil,
              namespace_id: group.id,
              start_date: start_date,
              end_date: end_date
            )
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

      context 'when namespace is nil' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            namespace: nil,
            start_date: start_date,
            end_date: end_date
          )
        end

        let(:client_response) { { success: true, poolUsage: {} } }

        it 'calls the client with nil namespace_id' do
          pool_usage

          expect(Gitlab::SubscriptionPortal::Client).to have_received(:get_subscription_pool_usage)
            .with(
              license_key: nil,
              namespace_id: nil,
              start_date: start_date,
              end_date: end_date
            )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          start_date: start_date,
          end_date: end_date
        )
      end

      let(:license) { create(:license) }
      let(:client_response) do
        {
          success: true,
          poolUsage: {
            totalUnits: 2000,
            unitsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'calls the subscription portal client with license key' do
        pool_usage

        expect(Gitlab::SubscriptionPortal::Client).to have_received(:get_subscription_pool_usage)
          .with(
            license_key: license.data,
            namespace_id: nil,
            start_date: start_date,
            end_date: end_date
          )
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

  describe '#users_usage' do
    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          namespace: group,
          start_date: start_date,
          end_date: end_date
        )
      end

      it 'includes namespace users in the users field' do
        expect(subscription_usage.users_usage.users).to match_array(users.first(2))
      end

      it 'sets declarative_policy_subject to SubscriptionUsage' do
        expect(subscription_usage.users_usage.declarative_policy_subject).to eq(subscription_usage)
      end

      context 'when namespace is nil' do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            namespace: nil,
            start_date: start_date,
            end_date: end_date
          )
        end

        it 'raises an error when trying to get users' do
          expect { subscription_usage.users_usage.users }.to raise_error(NoMethodError)
        end
      end

      context 'when namespace has no users' do
        let(:no_members_namespace) { create(:group) }
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :namespace,
            namespace: no_members_namespace,
            start_date: start_date,
            end_date: end_date
          )
        end

        it 'returns empty collection' do
          expect(subscription_usage.users_usage.users).to be_empty
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          start_date: start_date,
          end_date: end_date
        )
      end

      it 'includes all users in the users field' do
        expect(subscription_usage.users_usage.users).to match_array(users)
      end

      it 'sets declarative_policy_subject to self' do
        expect(subscription_usage.users_usage.declarative_policy_subject).to eq(subscription_usage)
      end
    end

    context 'when subscription_target is unknown' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :unknown,
          start_date: start_date,
          end_date: end_date
        )
      end

      it 'returns nil for unknown subscription target' do
        expect(subscription_usage.users_usage.users).to be_nil
      end
    end
  end
end
