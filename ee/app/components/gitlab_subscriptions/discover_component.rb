# frozen_string_literal: true

module GitlabSubscriptions
  class DiscoverComponent < ViewComponent::Base
    include SafeFormatHelper
    include BillingPlansHelper

    def initialize(namespace:)
      @namespace = namespace
    end

    private

    attr_reader :namespace

    delegate :page_title, to: :helpers

    def plans_data
      current_plan = namespace.plan_name_for_upgrading

      GitlabSubscriptions::FetchSubscriptionPlansService
        .new(plan: current_plan, namespace_id: namespace.id)
        .execute
    end

    def buy_now_link
      premium_plan = find_plan(plans_data, ::Plan::PREMIUM)

      plan_purchase_url(namespace, premium_plan)
    end

    def trial_days_remaining
      return 0 unless namespace.trial_active?

      trial_status = GitlabSubscriptions::TrialStatus.new(namespace.trial_starts_on, namespace.trial_ends_on)

      trial_status.days_remaining
    end
  end
end
