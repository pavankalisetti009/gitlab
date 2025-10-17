# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    include ::Gitlab::Utils::StrongMemoize

    PoolUsage = Struct.new(:total_credits, :credits_used, :daily_usage, :declarative_policy_subject)
    Overage = Struct.new(:is_allowed, :credits_used, :daily_usage, :declarative_policy_subject)
    DailyUsage = Struct.new(:date, :credits_used, :declarative_policy_subject)
    UsersUsage = Struct.new(:usage_stats, :users, :declarative_policy_subject) do
      def total_users_using_credits
        usage_stats.call[:totalUsersUsingCredits]
      end

      def total_users_using_pool
        usage_stats.call[:totalUsersUsingPool]
      end

      def total_users_using_overage
        usage_stats.call[:totalUsersUsingOverage]
      end
    end

    def initialize(
      subscription_target:,
      subscription_usage_client:,
      namespace: nil
    )
      @subscription_target = subscription_target
      @namespace = namespace
      @subscription_usage_client = subscription_usage_client
      @license_key = License.current&.data if subscription_target == :instance
    end

    attr_reader :namespace, :subscription_usage_client

    def start_date
      usage_metadata[:startDate]
    end

    def end_date
      usage_metadata[:endDate]
    end

    def last_updated
      usage_metadata[:lastUpdated]
    end

    def purchase_credits_path
      usage_metadata[:purchaseCreditsPath]
    end

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
      UsersUsage.new(
        usage_stats: -> { users_usage_stats },
        users: all_users,
        declarative_policy_subject: self
      )
    end
    strong_memoize_attr :users_usage

    private

    attr_reader :subscription_target, :license_key

    def all_users
      case subscription_target
      when :namespace
        namespace.users
      when :instance
        User.all
      end
    end

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

    def users_usage_stats
      subscription_usage_client.get_users_usage_stats[:usersUsage] || {}
    end
    strong_memoize_attr :users_usage_stats
  end
end
