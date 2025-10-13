# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsagePolicy, feature_category: :consumables_cost_management do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  describe ':read_subscription_usage' do
    let(:policy) { :read_subscription_usage }

    context 'when namespace is present' do
      let(:subscription_usage) do
        GitlabSubscriptions::SubscriptionUsage.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      # only admin and owner are allowed
      where(:user, :admin_mode, :result) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | true
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject(:allowed) { described_class.new(user, subscription_usage).allowed?(:read_subscription_usage) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when namespace is nil, in Self-Managed instance context' do
      let(:subscription_usage) do
        GitlabSubscriptions::SubscriptionUsage.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      # only admin is allowed
      where(:user, :admin_mode, :result) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | false
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject { described_class.new(user, subscription_usage).allowed?(:read_subscription_usage) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { is_expected.to eq(result) }
      end
    end
  end
end
