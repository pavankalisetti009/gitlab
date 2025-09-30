# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionUsagePolicy < ::BasePolicy
    condition(:namespace_owner) do
      can?(:owner_access, @subject.namespace)
    end

    rule { admin | namespace_owner }.policy do
      enable :read_subscription_usage
    end
  end
end
