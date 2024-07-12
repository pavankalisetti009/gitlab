# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoProStatus
      TIME_FRAME_AFTER_EXPIRATION = 10.days
      private_constant :TIME_FRAME_AFTER_EXPIRATION

      def initialize(add_on_purchase:)
        @add_on_purchase = add_on_purchase
      end

      def show?
        add_on_purchase.present? && active_or_recently_expired?
      end

      private

      attr_reader :add_on_purchase

      def active_or_recently_expired?
        Date.current <= add_on_purchase.expires_on + TIME_FRAME_AFTER_EXPIRATION
      end
    end
  end
end
