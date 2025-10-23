# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    include ::Gitlab::Utils::StrongMemoize

    OneTimeCredits = Struct.new(:credits_used, :total_credits, :total_credits_remaining, :declarative_policy_subject)
    PoolUsage = Struct.new(:total_credits, :credits_used, :daily_usage, :declarative_policy_subject)
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

    def one_time_credits
      one_time_credits_response = subscription_usage_client.get_one_time_credits

      return unless one_time_credits_response[:success]

      OneTimeCredits.new(
        credits_used: one_time_credits_response.dig(:oneTimeCredits, :creditsUsed),
        total_credits: one_time_credits_response.dig(:oneTimeCredits, :totalCredits),
        total_credits_remaining: one_time_credits_response.dig(:oneTimeCredits, :totalCreditsRemaining),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :one_time_credits

    def pool_usage
      pool_usage_response = subscription_usage_client.get_pool_usage

      return unless pool_usage_response[:success]

      PoolUsage.new(
        total_credits: pool_usage_response.dig(:poolUsage, :totalCredits),
        credits_used: pool_usage_response.dig(:poolUsage, :creditsUsed),
        daily_usage: build_daily_usage(pool_usage_response.dig(:poolUsage, :dailyUsage)),
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :pool_usage

    def overage
      overage_usage_response = subscription_usage_client.get_overage_usage

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
