# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsage, feature_category: :consumables_cost_management do
  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }

  describe '#users_usage' do
    context 'when subscription_target is :namespace' do
      let(:subscription_usage) { described_class.new(subscription_target: :namespace, namespace: group) }

      it 'includes namespace users in the users field' do
        expect(subscription_usage.users_usage.users).to match_array(users.first(2))
      end

      it 'sets declarative_policy_subject to SubscriptionUsage' do
        expect(subscription_usage.users_usage.declarative_policy_subject).to eq(subscription_usage)
      end

      context 'when namespace is nil' do
        let(:subscription_usage) { described_class.new(subscription_target: :namespace, namespace: nil) }

        it 'raises an error when trying to get users' do
          expect { subscription_usage.users_usage.users }.to raise_error(NoMethodError)
        end
      end

      context 'when namespace has no users' do
        let(:no_members_namespace) { create(:group) }
        let(:subscription_usage) do
          described_class.new(subscription_target: :namespace, namespace: no_members_namespace)
        end

        it 'returns empty collection' do
          expect(subscription_usage.users_usage.users).to be_empty
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) { described_class.new(subscription_target: :instance) }

      it 'includes all users in the users field' do
        expect(subscription_usage.users_usage.users).to match_array(users)
      end

      it 'sets declarative_policy_subject to self' do
        expect(subscription_usage.users_usage.declarative_policy_subject).to eq(subscription_usage)
      end
    end

    context 'when subscription_target is unknown' do
      let(:subscription_usage) { described_class.new(subscription_target: :unknown) }

      it 'returns nil for unknown subscription target' do
        expect(subscription_usage.users_usage.users).to be_nil
      end
    end
  end
end
