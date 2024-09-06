# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoProStatusWidgetPresenter, :saas, feature_category: :acquisition do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:group) { build(:group) }
  let(:add_on_purchase) do
    build(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :active_trial, namespace: group)
  end

  before do
    build(:gitlab_subscription, :ultimate, namespace: group)
    allow(GitlabSubscriptions::Trials::DuoPro).to receive(:add_on_purchase_for_namespace)
    allow(GitlabSubscriptions::Trials::DuoPro)
      .to receive(:add_on_purchase_for_namespace).with(group).and_return(add_on_purchase)
  end

  describe '#attributes' do
    subject { described_class.new(group, user: user).attributes }

    specify do
      freeze_time do
        # set here to ensure no date barrier flakiness
        add_on_purchase.expires_on = 60.days.from_now

        duo_pro_trial_status_widget_data_attrs = {
          trial_days_used: 1,
          trial_duration: 60,
          percentage_complete: 1.67,
          group_id: group.id,
          feature_id: described_class::EXPIRED_DUO_PRO_TRIAL_WIDGET,
          dismiss_endpoint: group_callouts_path
        }
        duo_pro_trial_status_popover_data_attrs = {
          days_remaining: 60,
          trial_end_date: 60.days.from_now.to_date,
          purchase_now_url:
            ::Gitlab::Routing.url_helpers.group_settings_gitlab_duo_usage_index_path(group),
          learn_about_button_url:
            ::Gitlab::Routing.url_helpers.group_add_ons_discover_duo_pro_path(group)
        }
        result = {
          duo_pro_trial_status_widget_data_attrs: duo_pro_trial_status_widget_data_attrs,
          duo_pro_trial_status_popover_data_attrs: duo_pro_trial_status_popover_data_attrs
        }

        is_expected.to eq(result)
      end
    end
  end

  describe '#eligible_for_widget?' do
    let(:root_group) { group }
    let(:current_user) { user }

    subject { described_class.new(root_group, user: current_user).eligible_for_widget? }

    it { is_expected.to be(true) }

    context 'without a duo pro trial add on' do
      let(:root_group) { build(:group) }

      it { is_expected.to be(false) }
    end

    context 'when the widget is dismissed' do
      before do
        allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
      end

      it { is_expected.to be(false) }
    end

    context 'when the widget is expired' do
      before do
        add_on_purchase.expires_on = 5.days.ago
      end

      it { is_expected.to be(true) }
    end
  end
end
