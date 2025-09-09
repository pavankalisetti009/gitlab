# frozen_string_literal: true

module Namespaces
  class AllSeatsUsedAlertComponent < ViewComponent::Base
    include SafeFormatHelper

    def initialize(context:, content_class:, current_user:)
      @root_namespace = context.root_ancestor
      @content_class = content_class
      @current_user = current_user
    end

    def render?
      return false unless feature_available?
      return false if root_namespace.free_plan? || block_seat_overages?
      return false unless owner? && group_namespace?

      all_seats_used?
    end

    private

    attr_reader :root_namespace, :content_class, :current_user

    def feature_available?
      Feature.enabled?(:notify_all_seats_used, root_namespace, type: :wip) &&
        ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end

    def alert_body
      safe_format(s_("SeatsManagement|Your namespace has used all the seats in your subscription. To avoid overages " \
        "from adding new users, consider %{settings_link_start}turning on restricted " \
        "access%{settings_link_end}, or %{more_seats_link_start}purchase more seats%{more_seats_link_end}."),
        settings_link,
        more_seats_link
      )
    end

    def all_seats_used?
      billable_members_count = root_namespace.billable_members_count_with_reactive_cache

      return false if billable_members_count.blank?

      subscription.seats <= billable_members_count
    end

    def block_seat_overages?
      subscription.has_a_paid_hosted_plan? && root_namespace.block_seat_overages?
    end

    def group_namespace?
      root_namespace.group_namespace?
    end

    def subscription
      root_namespace.gitlab_subscription
    end

    def owner?
      Ability.allowed?(current_user, :owner_access, root_namespace)
    end

    def more_seats_link
      link = link_to('', help_page_path('subscriptions/manage_users_and_seats.md', anchor: 'buy-more-seats'))

      tag_pair(link, :more_seats_link_start, :more_seats_link_end)
    end

    def settings_link
      link = link_to('', help_page_path('user/group/manage.md', anchor: "turn-on-restricted-access"))

      tag_pair(link, :settings_link_start, :settings_link_end)
    end
  end
end
