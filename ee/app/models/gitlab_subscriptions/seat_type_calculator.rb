# frozen_string_literal: true

module GitlabSubscriptions
  class SeatTypeCalculator
    BASE_SEAT = :base
    FREE_SEAT = :free
    PLAN_SEAT = :plan
    SYSTEM_SEAT = :system

    FREE_TIER = :free
    PREMIUM_TIER = :premium
    ULTIMATE_TIER = :ultimate

    SEAT_TYPE_MAPPINGS = {
      premium: {
        ::Gitlab::Access::MINIMAL_ACCESS => FREE_SEAT,
        ::Gitlab::Access::GUEST => BASE_SEAT,
        ::Gitlab::Access::PLANNER => BASE_SEAT,
        ::Gitlab::Access::REPORTER => BASE_SEAT,
        ::Gitlab::Access::DEVELOPER => BASE_SEAT,
        ::Gitlab::Access::MAINTAINER => BASE_SEAT,
        ::Gitlab::Access::OWNER => BASE_SEAT
      },
      ultimate: {
        ::Gitlab::Access::MINIMAL_ACCESS => FREE_SEAT,
        ::Gitlab::Access::GUEST => FREE_SEAT,
        ::Gitlab::Access::PLANNER => PLAN_SEAT,
        ::Gitlab::Access::REPORTER => BASE_SEAT,
        ::Gitlab::Access::DEVELOPER => BASE_SEAT,
        ::Gitlab::Access::MAINTAINER => BASE_SEAT,
        ::Gitlab::Access::OWNER => BASE_SEAT
      }
    }.freeze

    class << self
      def execute(user, namespace)
        return unless gitlab_com?

        tier = subscription_tier(namespace)
        access_level = find_highest_membership(user, namespace)&.access_level
        calculate_seat_type(user, tier, access_level)
      end

      def bulk_execute(users, namespace)
        return {} unless gitlab_com?

        tier = subscription_tier(namespace)
        access_levels = Member.seat_assignable_highest_access_levels(users: users, namespace: namespace)
        users.compact.each_with_object({}) do |user, hash|
          hash[user.id] = calculate_seat_type(user, tier, access_levels[user.id])
        end
      end

      private

      def gitlab_com?
        ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def find_highest_membership(user, namespace)
        Member.seat_assignable(users: user, namespace: namespace).order_access_level_desc.first
      end

      def calculate_seat_type(user, tier, access_level)
        return unless access_level
        return SYSTEM_SEAT if user.bot?
        return BASE_SEAT if tier == FREE_TIER

        SEAT_TYPE_MAPPINGS.dig(tier, access_level)
      end

      def subscription_tier(namespace)
        return FREE_TIER if namespace.free_plan?

        namespace.exclude_guests? ? ULTIMATE_TIER : PREMIUM_TIER
      end
    end
  end
end
