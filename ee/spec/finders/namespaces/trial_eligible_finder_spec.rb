# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::TrialEligibleFinder, feature_category: :subscription_management do
  describe '#execute', :saas do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    context 'with no params' do
      let_it_be(:namespace) { create(:group) }

      subject(:execute) { described_class.new.execute }

      it 'raises an error' do
        expect { execute }.to raise_error(ArgumentError, 'User or Namespace must be provided')
      end
    end

    context 'with namespace' do
      let_it_be(:namespace) { create(:group) }

      before_all do
        create(:group)
      end

      subject { described_class.new(namespace: namespace).execute }

      it { is_expected.to match_array(namespace) }
    end

    context 'with user' do
      let_it_be(:user) { create :user }

      subject(:execute) { described_class.new(user: user).execute }

      context 'when user does not own namespaces' do
        before_all do
          create(:group)
        end

        it { is_expected.to be_empty }
      end

      context 'when user owns namespaces' do
        let_it_be(:regular_namespace) { create(:group, name: 'Zeta', owners: user) }
        let_it_be(:namespace_with_free_plan) { create(:group_with_plan, name: 'Rho', plan: :free_plan, owners: user) }
        let_it_be(:namespace_with_premium_plan) do
          create(:group_with_plan, name: 'Alpha', plan: :premium_plan, owners: user)
        end

        let(:eligible_namespaces) do
          [
            namespace_with_premium_plan,
            namespace_with_free_plan,
            regular_namespace
          ]
        end

        before_all do
          create(:group, parent: regular_namespace)
          create(:group_with_plan, plan: :ultimate_trial_plan, owners: user)
        end

        it { is_expected.to eq(eligible_namespaces) }

        context 'when namespace is provided' do
          subject(:execute) { described_class.new(user: user, namespace: namespace_with_free_plan).execute }

          it 'raises an error' do
            expect { execute }.to raise_error(ArgumentError, 'Only User or Namespace can be provided, not both')
          end
        end

        context 'when a duo enterprise add on exists on a namespace' do
          before do
            create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on, namespace: regular_namespace)
          end

          it 'is not eligible for the trial' do
            is_expected.to eq([namespace_with_premium_plan, namespace_with_free_plan])
          end
        end

        context 'when a duo pro add on exists on a namespace' do
          context 'and a namespace has an active purchase' do
            before do
              create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on, namespace: regular_namespace)
            end

            it 'is eligible for the trial' do
              is_expected.to eq(eligible_namespaces)
            end
          end

          context 'and a namespace has an expired purchase' do
            before do
              create(
                :gitlab_subscription_add_on_purchase, :expired, add_on: duo_pro_add_on, namespace: regular_namespace
              )
            end

            it 'is eligible for the trial' do
              is_expected.to eq(eligible_namespaces)
            end
          end

          context 'and a namespace has an active trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :active_trial, add_on: duo_pro_add_on, namespace: regular_namespace
              )
            end

            it 'is not eligible for the trial' do
              is_expected.to eq([namespace_with_premium_plan, namespace_with_free_plan])
            end
          end

          context 'and a namespace has an expired trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :expired_trial, add_on: duo_pro_add_on, namespace: regular_namespace
              )
            end

            it 'is eligible for the trial' do
              is_expected.to eq(eligible_namespaces)
            end
          end

          context 'and a namespace has a future active trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :future_dated, add_on: duo_pro_add_on, trial: true, namespace: regular_namespace
              )
            end

            it 'is eligible for the trial' do
              is_expected.to eq(eligible_namespaces)
            end
          end
        end
      end
    end
  end
end
