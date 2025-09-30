# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsage
    UsersUsage = Struct.new(:users, :declarative_policy_subject)

    def initialize(subscription_target:, namespace: nil)
      @subscription_target = subscription_target
      @namespace = namespace
    end

    attr_reader :subscription_target, :namespace

    def users_usage
      UsersUsage.new(
        users: all_users,
        declarative_policy_subject: self
      )
    end

    private

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
