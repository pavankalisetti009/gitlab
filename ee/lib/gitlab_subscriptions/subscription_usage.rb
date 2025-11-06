# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    include ::Gitlab::Utils::StrongMemoize

    MonthlyWaiver = Struct.new(:total_credits, :credits_used, :declarative_policy_subject)
    MonthlyCommitment = Struct.new(:total_credits, :credits_used, :daily_usage, :declarative_policy_subject)
    Overage = Struct.new(:is_allowed, :credits_used, :daily_usage, :declarative_policy_subject)
    DailyUsage = Struct.new(:date, :credits_used, :declarative_policy_subject)

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
      usage_metadata[:purchaseCreditsPath]
    end

    def monthly_waiver
      monthly_waiver_response = subscription_usage_client.get_monthly_waiver

      return unless monthly_waiver_response[:success]

      MonthlyWaiver.new(
        total_credits: monthly_waiver_response.dig(:monthlyWaiver, :totalCredits),
        credits_used: monthly_waiver_response.dig(:monthlyWaiver, :creditsUsed),
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
