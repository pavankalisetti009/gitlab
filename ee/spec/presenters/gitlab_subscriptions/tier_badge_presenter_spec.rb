# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TierBadgePresenter, :saas, feature_category: :subscription_management do
  describe '#attributes' do
    let(:namespace) { build(:gitlab_subscription, :free, namespace: build_stubbed(:group)).namespace }
    let(:user) { build_stubbed(:user) }

    subject(:attributes) { described_class.new(user, namespace: namespace).attributes }

    context 'when user can edit billing' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(true)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when namespace is present and persisted' do
        context 'when namespace is on free plan' do
          it 'returns the correct attributes' do
            expect(attributes).to eq({
              tier_badge_href: "/groups/#{namespace.path}/-/billings?source=sidebar-free-tier-highlight"
            })
          end
        end

        context 'when gitlab_com_subscriptions feature is not available' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end
      end

      context 'when namespace is not on free plan' do
        let(:namespace) { build(:gitlab_subscription, :premium, namespace: build_stubbed(:group)).namespace }

        it 'returns empty hash' do
          expect(attributes).to eq({})
        end
      end

      context 'when namespace is not yet persisted' do
        let(:namespace) { build(:namespace) }

        it 'returns empty hash' do
          expect(attributes).to eq({})
        end
      end
    end

    context 'when user can not edit billing' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(false)
      end

      context 'when namespace is present and on free plan' do
        it 'returns an empty hash' do
          expect(attributes).to eq({})
        end
      end
    end
  end
end
