# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    include ::Gitlab::Utils::StrongMemoize

    MonthlyWaiver = Struct.new(:total_credits, :credits_used, :daily_usage, :declarative_policy_subject)
    MonthlyCommitment = Struct.new(:total_credits, :credits_used, :daily_usage, :declarative_policy_subject)
    Overage = Struct.new(:is_allowed, :credits_used, :daily_usage, :declarative_policy_subject)
    DailyUsage = Struct.new(:date, :credits_used, :declarative_policy_subject)
    PaidTierTrial = Struct.new(:is_active, :daily_usage, :declarative_policy_subject)

    def initialize(
      subscription_target:,
      subscription_usage_client:,
      namespace: nil
    )
      @subscription_target = subscription_target
      @namespace = namespace
      @subscription_usage_client = subscription_usage_client
    end

    attr_reader :namespace, :subscription_usage_client, :subscription_target

    def enabled?
      !!usage_metadata[:enabled]
    end

    def outdated_client?
      usage_metadata[:isOutdatedClient]
    end

    def start_date
      usage_metadata[:startDate]
    end

    def end_date
      usage_metadata[:endDate]
    end

    def last_event_transaction_at
      usage_metadata[:lastEventTransactionAt]
    end

    def purchase_credits_path
      return unless enabled?

      is_gitlab_com = ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      return if is_gitlab_com && namespace.nil?
      return if !is_gitlab_com && License.current&.subscription_name.nil?

      deployment_type = is_gitlab_com ? 'gitlab_com' : 'self_managed'
      params = {
        deployment_type: deployment_type,
        plan_type: 'gitlab_credits',
        gl_namespace_id: is_gitlab_com ? namespace.root_ancestor&.id : nil,
        subscription_name: is_gitlab_com ? nil : License.current.subscription_name
      }.compact

      "/subscriptions/purchases/gitlab?#{params.to_query}"
    end

    def overage_terms_accepted
      !!usage_metadata[:overageTermsAccepted]
    end

    def can_accept_overage_terms
      !!usage_metadata[:canAcceptOverageTerms]
    end

    def dap_promo_enabled
      !!usage_metadata[:dapPromoEnabled]
    end

    def usage_dashboard_path
      usage_metadata[:usageDashboardPath]
    end

    def monthly_waiver
      monthly_waiver_response = subscription_usage_client.get_monthly_waiver

      return unless monthly_waiver_response[:success]

      MonthlyWaiver.new(
        total_credits: monthly_waiver_response.dig(:monthlyWaiver, :totalCredits),
        credits_used: monthly_waiver_response.dig(:monthlyWaiver, :creditsUsed),
        daily_usage: build_daily_usage(monthly_waiver_response.dig(:monthlyWaiver, :dailyUsage)),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :monthly_waiver

    def monthly_commitment
      monthly_commitment_response = subscription_usage_client.get_monthly_commitment

      return unless monthly_commitment_response[:success]

      MonthlyCommitment.new(
        total_credits: monthly_commitment_response.dig(:monthlyCommitment, :totalCredits),
        credits_used: monthly_commitment_response.dig(:monthlyCommitment, :creditsUsed),
        daily_usage: build_daily_usage(monthly_commitment_response.dig(:monthlyCommitment, :dailyUsage)),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :monthly_commitment

    def overage
      overage_usage_response = subscription_usage_client.get_overage

      return unless overage_usage_response[:success]

      Overage.new(
        is_allowed: overage_usage_response.dig(:overage, :isAllowed),
        credits_used: overage_usage_response.dig(:overage, :creditsUsed),
        daily_usage: build_daily_usage(overage_usage_response.dig(:overage, :dailyUsage)),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :overage

    def users_usage
      SubscriptionsUsage::UserUsage.new(
        subscription_usage: self
      )
    end
    strong_memoize_attr :users_usage

    def subscription_portal_usage_dashboard_url
      return unless can_accept_overage_terms

      path = usage_dashboard_path
      return if path.blank?

      "#{::Gitlab::SubscriptionPortal.default_production_customer_portal_url}#{path}"
    end
    strong_memoize_attr :subscription_portal_usage_dashboard_url

    def paid_tier_trial
      paid_tier_trial_response = subscription_usage_client.get_paid_tier_trial

      PaidTierTrial.new(
        is_active: !!paid_tier_trial_response.dig(:paidTierTrial, :isActive),
        daily_usage: build_daily_usage(paid_tier_trial_response.dig(:paidTierTrial, :dailyUsage)),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :paid_tier_trial

    private

    def build_daily_usage(daily_usage)
      daily_usage.to_a.map do |usage|
        DailyUsage.new(
          date: usage[:date],
          credits_used: usage[:creditsUsed],
          declarative_policy_subject: self
        )
      end
    end

    def usage_metadata
      subscription_usage_client.get_metadata[:subscriptionUsage] || {}
    end
    strong_memoize_attr :usage_metadata
  end
end
