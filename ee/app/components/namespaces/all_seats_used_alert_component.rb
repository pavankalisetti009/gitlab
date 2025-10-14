# frozen_string_literal: true

module Namespaces
  class AllSeatsUsedAlertComponent < ViewComponent::Base
    include SafeFormatHelper

    def initialize(context:)
      @root_namespace = context.root_ancestor
    end

    private

    attr_reader :root_namespace

    def render?
      Feature.enabled?(:notify_all_seats_used, root_namespace, type: :wip) && !root_namespace.free_plan?
    end

    def alert_body
      safe_format(s_("SeatsManagement|Your namespace has used all the seats in your subscription. To avoid overages " \
        "from adding new users, consider %{settings_link_start}turning on restricted " \
        "access%{settings_link_end}, or %{more_seats_link_start}purchase more seats%{more_seats_link_end}."),
        settings_link,
        more_seats_link
      )
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
