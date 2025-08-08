# frozen_string_literal: true

module GitlabSubscriptions
  class SeatTypeCalculator
    BASE_SEAT = :base
    FREE_SEAT = :free
    PLAN_SEAT = :plan
    SYSTEM_SEAT = :system

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

    def initialize(user, namespace)
      @user = user
      @namespace = namespace
    end

    def execute
      return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      validate!

      calculate_seat_type
    end

    private

    attr_reader :user, :namespace

    def validate!
      raise ArgumentError, 'User must be present' if user.nil?
      raise ArgumentError, 'Namespace must be present' if namespace.nil?
    end

    def calculate_seat_type
      return SYSTEM_SEAT if user.bot?

      member = find_highest_membership
      return unless member

      seat_type_for_active_user(member)
    end

    def seat_type_for_active_user(member)
      return :base if subscription_tier == :free

      highest_access_level = member.access_level
      seat_type_for_tier(highest_access_level)
    end

    def find_highest_membership
      user.members
        .in_hierarchy(namespace)
        .with_user(user)
        .without_invites_and_requests(minimal_access: true)
        .order_access_level_desc
        .first
    end

    def subscription_tier
      return :free if namespace.free_plan?

      namespace.exclude_guests? ? :ultimate : :premium
    end

    def seat_type_for_tier(access_level)
      SEAT_TYPE_MAPPINGS.dig(subscription_tier, access_level)
    end
  end
end
