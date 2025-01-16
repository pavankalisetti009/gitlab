# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::StatusWidgetPresenter, :saas, feature_category: :acquisition do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:group) { build(:group) }
  let(:trial_duration) { 60 }

  let(:add_on_purchase) do
    build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active_trial, namespace: group,
      started_at: Date.current, expires_on: trial_duration.days.from_now)
  end

  let(:presenter) { described_class.new(group, user: user) }

  describe '#eligible_for_widget?' do
    subject(:eligible_for_widget) { presenter.eligible_for_widget? }

    context 'when trial is active' do
      before do
        build(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: group,
          trial_starts_on: Time.current, trial_ends_on: trial_duration.days.from_now)
      end

      it { is_expected.to be(true) }
    end

    context 'when trial is active and group is paid' do
      before do
        build(:gitlab_subscription, :ultimate_trial_paid_customer, namespace: group,
          trial_starts_on: Time.current, trial_ends_on: trial_duration.days.from_now)
      end

      it { is_expected.to be(true) }
    end

    context 'when trial has just ended and group is unpaid' do
      before do
        build(:gitlab_subscription, :free, :expired_trial, namespace: group,
          trial_starts_on: (trial_duration + 5).days.ago,
          trial_ends_on: 5.days.ago)
      end

      it { is_expected.to be(true) }

      context 'when widget is dismissed' do
        let(:user) do
          build(:user, group_callouts: [
            build(:group_callout, group: group, feature_name: described_class::EXPIRED_TRIAL_WIDGET)
          ])
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when trial ended more than 10 days ago' do
      before do
        build(:gitlab_subscription, :free, :expired_trial, namespace: group,
          trial_starts_on: (trial_duration + 11).days.ago,
          trial_ends_on: 11.days.ago)
      end

      it { is_expected.to be(false) }
    end

    context 'when group is on a paid plan' do
      before do
        build(:gitlab_subscription, :premium, namespace: group)
      end

      it { is_expected.to be(false) }
    end

    context 'when duo enterprise is available' do
      before do
        allow(GitlabSubscriptions::Trials::DuoEnterprise)
          .to receive(:any_add_on_purchase_for_namespace).with(group).and_return(add_on_purchase)
      end

      context 'when trial is active' do
        it { is_expected.to be(true) }
      end

      context 'when trial has just ended and group is unpaid' do
        let(:add_on_purchase) do
          build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired_trial, namespace: group)
        end

        it { is_expected.to be(true) }

        context 'when widget is dismissed' do
          let(:user) do
            build(:user, group_callouts: [
              build(:group_callout, group: group, feature_name: described_class::EXPIRED_TRIAL_WIDGET)
            ])
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when trial ended more than 10 days ago' do
        let(:add_on_purchase) do
          build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired_trial, namespace: group,
            started_at: (trial_duration + 11).days.ago, expires_on: 11.days.ago)
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#attributes' do
    subject(:attributes) { presenter.attributes }

    before do
      build(:gitlab_subscription, :active_trial, :ultimate_trial, namespace: group,
        trial_starts_on: Date.current, trial_ends_on: trial_duration.days.from_now)
    end

    context 'when duo enterprise is available' do
      before do
        allow(GitlabSubscriptions::Trials::DuoEnterprise)
          .to receive(:any_add_on_purchase_for_namespace).with(group).and_return(add_on_purchase)
      end

      it 'returns ultimate type and correct discover page path for bundled trials' do
        expect(attributes).to eq(
          trial_widget_data_attrs: {
            trial_type: 'ultimate',
            trial_days_used: 1,
            days_remaining: trial_duration,
            percentage_complete: 1.67,
            group_id: group.id,
            trial_discover_page_path: group_discover_path(group),
            purchase_now_url: group_billings_path(group),
            feature_id: described_class::EXPIRED_TRIAL_WIDGET,
            dismiss_endpoint: group_callouts_path
          }
        )
      end
    end
  end
end
