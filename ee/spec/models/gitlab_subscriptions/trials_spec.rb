# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials, feature_category: :subscription_management do
  describe '.single_eligible_namespace?' do
    subject { described_class.single_eligible_namespace?(eligible_namespaces) }

    context 'when there are multiple namespaces' do
      let(:eligible_namespaces) { build_list(:namespace, 2) }

      it { is_expected.to be(false) }
    end

    context 'when there is one namespace' do
      let(:eligible_namespaces) { [build(:namespace)] }

      it { is_expected.to be(true) }
    end

    context 'when there are no namespaces' do
      let(:eligible_namespaces) { [] }

      it { is_expected.to be(false) }
    end
  end

  describe '.namespace_eligible?', :saas do
    subject { described_class.namespace_eligible?(namespace) }

    context 'with a plan that is eligible for a trial' do
      where(plan: ::Plan::PLANS_ELIGIBLE_FOR_COMBINED_TRIAL)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(true) }
      end
    end

    context 'with a plan that is ineligible for a trial' do
      where(plan: ::Plan::PAID_HOSTED_PLANS.without(::Plan::PREMIUM))

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(false) }
      end
    end

    context 'when duo_enterprise_trials_registration feature flag is disabled' do
      let(:namespace) { build(:namespace) }

      before do
        stub_feature_flags(duo_enterprise_trials_registration: false)
      end

      it { is_expected.to be(true) }

      context 'when namespace is already on a trial' do
        let_it_be(:namespace) { create(:group_with_plan, plan: :free_plan, trial_ends_on: 1.year.ago) }

        it { is_expected.to be(false) }
      end
    end
  end
end
