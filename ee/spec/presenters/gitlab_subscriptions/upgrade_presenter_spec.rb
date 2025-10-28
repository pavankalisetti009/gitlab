# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UpgradePresenter, :saas, feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:namespace) { nil }

  describe '#attributes' do
    subject(:attributes) { described_class.new(user, namespace: namespace).attributes }

    context 'when gitlab_com_subscriptions feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns empty hash' do
        expect(attributes).to eq({})
      end
    end

    context 'when gitlab_com_subscriptions feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'without namespace provided' do
        context 'when user has no owned free or trial groups' do
          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return(Group.none)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end

        context 'when user has exactly one free or trial group' do
          let(:group) { build_stubbed(:group) }

          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([group])
          end

          it 'returns upgrade_url pointing to the group billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(group)
            expect(attributes).to eq({ upgrade_url: expected_path })
          end
        end

        context 'when user has multiple free or trial groups' do
          let(:group1) { build_stubbed(:group) }
          let(:group2) { build_stubbed(:group) }

          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([group1, group2])
          end

          it 'returns upgrade_url pointing to profile billings path' do
            expected_path = ::Gitlab::Routing.url_helpers.profile_billings_path
            expect(attributes).to eq({ upgrade_url: expected_path })
          end
        end
      end

      context 'with namespace provided' do
        let(:namespace) { build_stubbed(:group) }

        context 'when user can edit billing and namespace is free or trial' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(true)
            allow(namespace).to receive_messages(paid?: false, trial?: false)
          end

          it 'returns upgrade_url for the specific namespace' do
            expected_path = ::Gitlab::Routing.url_helpers.group_billings_path(namespace)
            expect(attributes).to eq({ upgrade_url: expected_path })
          end
        end

        context 'when user cannot edit billing' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(false)
            allow(namespace).to receive_messages(paid?: false, trial?: false)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end

        context 'when namespace is paid and not trial' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :edit_billing, namespace).and_return(true)
            allow(namespace).to receive_messages(paid?: true, trial?: false)
          end

          it 'returns empty hash' do
            expect(attributes).to eq({})
          end
        end
      end

      context 'with caching behavior', :use_clean_rails_memory_store_caching do
        let(:cache_key) { ['users', user.id, 'owned_groups_url'] }

        context 'when cache is empty' do
          before do
            allow(user).to receive(:owned_free_or_trial_groups_with_limit).with(2).and_return([])
          end

          it 'fetches data and caches it' do
            expect(Rails.cache).to receive(:fetch)
              .with(cache_key, expires_in: 10.minutes)
              .and_call_original

            attributes
          end

          it 'stores nil in cache when no groups' do
            attributes

            cached_data = Rails.cache.read(cache_key)
            expect(cached_data).to be_nil
          end
        end

        context 'when cache exists' do
          let(:cached_url) { 'cached_url' }

          before do
            Rails.cache.write(cache_key, cached_url)
          end

          it 'uses cached data without database query' do
            expect(user).not_to receive(:owned_free_or_trial_groups_with_limit)

            result = attributes
            expect(result[:upgrade_url]).to eq(cached_url)
          end
        end
      end
    end
  end
end
