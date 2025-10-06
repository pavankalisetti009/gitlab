# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    PoolUsage = Struct.new(:total_credits, :credits_used, :declarative_policy_subject)
    UsersUsage = Struct.new(:users, :declarative_policy_subject)

    def initialize(
      subscription_target:,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      namespace: nil
    )
      @subscription_target = subscription_target
      @namespace = namespace
      @start_date = start_date
      @end_date = end_date
      @license_key = License.current&.data if subscription_target == :instance
    end

    attr_reader :namespace, :start_date, :end_date

    def pool_usage
      pool_usage_response = Gitlab::SubscriptionPortal::Client.get_subscription_pool_usage(
        license_key: license_key,
        namespace_id: namespace&.id,
        start_date: start_date,
        end_date: end_date
      )

      return unless pool_usage_response[:success]

      PoolUsage.new(
        total_credits: pool_usage_response.dig(:poolUsage, :totalUnits),
        credits_used: pool_usage_response.dig(:poolUsage, :unitsUsed),
        declarative_policy_subject: self
      )
    end

    def users_usage
      UsersUsage.new(
        users: all_users,
        declarative_policy_subject: self
      )
    end

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
  end
end
