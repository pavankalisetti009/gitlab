# frozen_string_literal: true

module Namespaces
  class ApproachingSeatCountThresholdComponent < ViewComponent::Base
    def initialize(context:, remaining_seat_count:, total_seat_count:)
      @namespace = context
      @remaining_seat_count = remaining_seat_count
      @total_seat_count = total_seat_count
    end

    private

    delegate :usage_quotas_path, :link_button_to, to: :helpers
    attr_reader :namespace, :remaining_seat_count, :total_seat_count

    def render?
      namespace.present?
    end

    def block_seat_overages?
      namespace.block_seat_overages?
    end

    def seat_count_text
      if block_seat_overages?
        return _('Once you reach the number of seats in your subscription, you can no longer ' \
          'invite or add users to the namespace.')
      end

      _('Even if you reach the number of seats in your subscription, you can continue to add users, ' \
        'and GitLab will bill you for the overage.')
    end

    def seat_count_help_page_link
      return help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access') if block_seat_overages?

      help_page_path('subscriptions/quarterly_reconciliation.md')
    end
  end
end
