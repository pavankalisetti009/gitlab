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

  describe '.eligible_namespace?' do
    context 'when namespace_id is blank' do
      it 'returns true for nil' do
        expect(described_class.eligible_namespace?(nil, [])).to be(true)
      end

      it 'returns true for empty string' do
        expect(described_class.eligible_namespace?('', [])).to be(true)
      end
    end

    context 'when namespace_id is present' do
      let_it_be(:namespace) { create(:group) }
      let(:eligible_namespaces) { Namespace.id_in(namespace.id) }

      it 'returns true for an eligible namespace' do
        expect(described_class.eligible_namespace?(namespace.id.to_s, eligible_namespaces)).to be(true)
      end

      it 'returns false for an in-eligible namespace' do
        expect(described_class.eligible_namespace?(non_existing_record_id.to_s, eligible_namespaces)).to be(false)
      end
    end
  end

  describe '.creating_group_trigger?' do
    subject { described_class.creating_group_trigger?(namespace_id) }

    where(:namespace_id, :expected_result) do
      [
        [0,   true],
        [nil, false],
        [1,   false]
      ]
    end

    with_them do
      it { is_expected.to be(expected_result) }
    end
  end

  describe '.namespace_eligible?', :saas, :use_clean_rails_memory_store_caching do
    let(:trial_types) { described_class::TRIAL_TYPES }
    let_it_be(:namespace) { create(:group) }

    before do
      Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
    end

    subject { described_class.namespace_eligible?(namespace) }

    context 'with a plan that is eligible for a trial' do
      where(plan: ::Plan::PLANS_ELIGIBLE_FOR_TRIAL)

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

    context 'with namespace that is ineligible for a trial due to trial_types' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be(false) }
    end
  end

  describe '.namespace_plan_eligible_for_active?', :saas do
    subject { described_class.namespace_plan_eligible_for_active?(namespace) }

    context 'with a plan that is on a trial' do
      where(plan: ::Plan::ULTIMATE_TRIAL_PLANS)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(true) }
      end
    end

    context 'with a plan that is not on a trial' do
      where(plan: ::Plan::PAID_HOSTED_PLANS.without(::Plan::ULTIMATE_TRIAL_PLANS))

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.namespace_add_on_eligible?', :use_clean_rails_memory_store_caching do
    let_it_be(:namespace) { create(:group) }

    subject(:execute) { described_class.namespace_add_on_eligible?(namespace) }

    context 'when ultimate_trial_with_dap FF is disabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE] }

      before do
        stub_feature_flags(ultimate_trial_with_dap: false)
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to be(true) }
    end

    context 'when ultimate_trial_with_dap FF is enabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2] }

      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to be(true) }
    end

    context 'when ineligible' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be(false) }
    end
  end

  describe '.eligible_namespaces_for_user', :use_clean_rails_memory_store_caching do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }

    subject { described_class.eligible_namespaces_for_user(user) }

    context 'when ultimate_trial_with_dap FF is disabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE] }

      before do
        stub_feature_flags(ultimate_trial_with_dap: false)
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to eq([namespace]) }
    end

    context 'when ultimate_trial_with_dap FF is enabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2] }

      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to eq([namespace]) }
    end

    context 'when ineligible' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be_empty }
    end
  end

  describe '.no_eligible_namespaces_for_user?', :use_clean_rails_memory_store_caching do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }

    subject { described_class.no_eligible_namespaces_for_user?(user) }

    context 'when ultimate_trial_with_dap FF is disabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE] }

      before do
        stub_feature_flags(ultimate_trial_with_dap: false)
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to be(false) }
    end

    context 'when ultimate_trial_with_dap FF is enabled' do
      let(:trial_types) { [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2] }

      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", trial_types)
      end

      it { is_expected.to be(false) }
    end

    context 'when no eligible namespaces exist' do
      let(:trial_types) { ['gitlab_duo_pro'] }

      it { is_expected.to be(true) }
    end
  end

  describe '.self_managed_non_dedicated_ultimate_trial?' do
    let(:license) { build(:license, :ultimate_trial) }

    subject { described_class.self_managed_non_dedicated_ultimate_trial?(license) }

    it { is_expected.to be(true) }

    context 'when plan is not ultimate' do
      let(:license) { build(:license, :trial) }

      it { is_expected.to be(false) }
    end

    context 'when it is not trial' do
      let(:license) { build(:license, :ultimate) }

      it { is_expected.to be(false) }
    end

    context 'when license is nil' do
      let(:license) { nil }

      it { is_expected.to be(false) }
    end

    context 'when GitLab Dedicated instance', :dedicated do
      it { is_expected.to be(false) }
    end
  end

  describe '.self_managed_non_dedicated_active_ultimate_trial?' do
    let(:license) { build(:license, :ultimate_trial) }

    subject { described_class.self_managed_non_dedicated_active_ultimate_trial?(license) }

    context 'when license is active' do
      it { is_expected.to be(true) }
    end

    context 'when license is not active' do
      let(:license) { build(:license, :ultimate_trial, expired: true) }

      it { is_expected.to be(false) }
    end

    context 'when GitLab Dedicated instance', :dedicated do
      it { is_expected.to be(false) }
    end
  end

  describe '#recently_expired?', :saas_gitlab_com_subscriptions do
    let(:group) { build(:group, id: non_existing_record_id, gitlab_subscription: gitlab_subscription) }
    let(:trial_ends_on) { 9.days.ago }

    let(:gitlab_subscription) do
      build(:gitlab_subscription, :expired_trial, :free, trial_ends_on: trial_ends_on)
    end

    subject { described_class.recently_expired?(group) }

    context 'when free group' do
      context 'when on 10th day of expiration' do
        it { is_expected.to be(true) }
      end

      context 'when on 11th day of expiration' do
        let(:trial_ends_on) { 10.days.ago }

        it { is_expected.to be(false) }
      end

      context 'when without trial' do
        let(:gitlab_subscription) { build(:gitlab_subscription, :free) }

        it { is_expected.to be(false) }
      end
    end

    context 'when paid group' do
      let(:gitlab_subscription) { build(:gitlab_subscription, :expired_trial, :ultimate) }

      it { is_expected.to be(false) }
    end
  end

  describe '.dap_type?', :saas_subscriptions_trials do
    let(:ultimate_with_dap_trial_uat_enabled) { false }

    before do
      stub_feature_flags(ultimate_with_dap_trial_uat: ultimate_with_dap_trial_uat_enabled)
    end

    subject { described_class.dap_type?(namespace) }

    context 'when trial is active' do
      context 'when ultimate_with_dap_trial_uat feature flag is enabled' do
        let(:ultimate_with_dap_trial_uat_enabled) { true }

        let(:namespace) do
          create(:group_with_plan, trial_ends_on: 15.days.from_now) do |group|
            group.gitlab_subscription.update!(
              trial: true,
              trial_starts_on: Date.new(2026, 2, 1)
            )
          end
        end

        it { is_expected.to be(true) }
      end

      context 'when trial started on or after ULTIMATE_WITH_DAP_TRIAL_START_DATE' do
        let(:namespace) do
          create(:group_with_plan, trial_ends_on: 15.days.from_now) do |group|
            group.gitlab_subscription.update!(
              trial: true,
              trial_starts_on: Date.new(2026, 2, 10)
            )
          end
        end

        it { is_expected.to be(true) }
      end

      context 'when trial started after ULTIMATE_WITH_DAP_TRIAL_START_DATE' do
        let(:namespace) do
          create(:group_with_plan, trial_ends_on: 15.days.from_now) do |group|
            group.gitlab_subscription.update!(
              trial: true,
              trial_starts_on: Date.new(2026, 2, 15)
            )
          end
        end

        it { is_expected.to be(true) }
      end

      context 'when trial started before ULTIMATE_WITH_DAP_TRIAL_START_DATE' do
        let(:namespace) do
          create(:group_with_plan, trial_ends_on: 15.days.from_now) do |group|
            group.gitlab_subscription.update!(
              trial: true,
              trial_starts_on: Date.new(2026, 2, 9)
            )
          end
        end

        before do
          stub_feature_flags(ultimate_with_dap_trial_uat: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when trial is not active' do
      let(:namespace) { create(:group) }

      it { is_expected.to be(true) }

      context 'when ultimate_trial_with_dap instance feature flag is disabled' do
        before do
          stub_feature_flags(ultimate_trial_with_dap: false)
        end

        it { is_expected.to be(false) }
      end
    end
  end
end
