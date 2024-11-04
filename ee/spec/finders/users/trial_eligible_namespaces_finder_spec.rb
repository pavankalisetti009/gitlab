# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::TrialEligibleNamespacesFinder, feature_category: :subscription_management do
  describe '#execute', :saas do
    let_it_be(:user) { create :user }

    subject(:execute) { described_class.new(user).execute }

    context 'when user does not own namespaces' do
      before_all do
        create(:group)
      end

      it { is_expected.to be_empty }
    end

    context 'when user owns namespaces' do
      let_it_be(:regular_namespace) { create(:group, owners: user) }
      let_it_be(:namespace_with_free_plan) { create(:group_with_plan, plan: :free_plan, owners: user) }
      let_it_be(:namespace_with_premium_plan) { create(:group_with_plan, plan: :premium_plan, owners: user) }
      let_it_be(:namespace_with_ultimate_trial) { create(:group_with_plan, plan: :ultimate_trial_plan, owners: user) }

      let(:eligible_namespaces) do
        [
          regular_namespace,
          namespace_with_free_plan,
          namespace_with_premium_plan
        ]
      end

      it { is_expected.to match_array(eligible_namespaces) }

      context 'when a duo enterprise add on exists on a namespace' do
        before do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: regular_namespace)
        end

        it 'is not eligible for the trial' do
          is_expected.to match_array([namespace_with_free_plan, namespace_with_premium_plan])
        end
      end

      context 'when a duo pro add on exists on a namespace' do
        context 'and a namespace has an active purchase' do
          before do
            create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: regular_namespace)
          end

          it 'is eligible for the trial' do
            is_expected.to match_array(eligible_namespaces)
          end
        end

        context 'and a namespace has an expired purchase' do
          before do
            create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired, namespace: regular_namespace)
          end

          it 'is eligible for the trial' do
            is_expected.to match_array(eligible_namespaces)
          end
        end

        context 'and a namespace has an active trial' do
          before do
            create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :active_trial, namespace: regular_namespace)
          end

          it 'is not eligible for the trial' do
            is_expected.to match_array([namespace_with_free_plan, namespace_with_premium_plan])
          end
        end

        context 'and a namespace has an expired trial' do
          before do
            create(
              :gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired_trial, namespace: regular_namespace
            )
          end

          it 'is eligible for the trial' do
            is_expected.to match_array(eligible_namespaces)
          end
        end

        context 'and a namespace has a future active trial' do
          before do
            create(
              :gitlab_subscription_add_on_purchase,
              :gitlab_duo_pro, :future_dated, trial: true, namespace: regular_namespace
            )
          end

          it 'is eligible for the trial' do
            is_expected.to match_array(eligible_namespaces)
          end
        end
      end
    end
  end
end
