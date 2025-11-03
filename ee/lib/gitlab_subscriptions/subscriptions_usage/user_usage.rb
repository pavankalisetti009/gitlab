# frozen_string_literal: true

module GitlabSubscriptions
  module SubscriptionsUsage
    class UserUsage
      include ::Gitlab::Utils::StrongMemoize

      def initialize(subscription_usage:)
        @subscription_usage = subscription_usage
      end

      def daily_usage
        usage_stats[:dailyUsage].to_a.map do |usage|
          GitlabSubscriptions::SubscriptionUsage::DailyUsage.new(
            date: usage[:date],
            credits_used: usage[:creditsUsed],
            declarative_policy_subject: declarative_policy_subject
          )
        end
      end
      strong_memoize_attr :daily_usage

      def total_users_using_credits
        usage_stats[:totalUsersUsingCredits]
      end

      def total_users_using_monthly_commitment
        usage_stats[:totalUsersUsingMonthlyCommitment]
      end

      def total_users_using_overage
        usage_stats[:totalUsersUsingOverage]
      end

      def credits_used
        usage_stats[:creditsUsed]
      end

      def users(username: nil)
        strong_memoize_with(:users, username) do
          case subscription_usage.subscription_target
          when :namespace
            if username.present?
              subscription_usage.namespace.users.by_username(username)
            else
              subscription_usage.namespace.users
            end
          when :instance
            username.present? ? User.by_username(username) : User.all
          end&.without_bots
        end
      end

      def declarative_policy_subject
        subscription_usage
      end

      private

      attr_reader :subscription_usage

      def usage_stats
        subscription_usage.subscription_usage_client.get_users_usage_stats[:usersUsage] || {}
      end
      strong_memoize_attr :usage_stats
    end
  end
end
