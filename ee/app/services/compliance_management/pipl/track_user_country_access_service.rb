# frozen_string_literal: true

module ComplianceManagement
  module Pipl
    class TrackUserCountryAccessService
      def initialize(user, country_code)
        @user = user
        @country_code = country_code
      end

      def execute
        return unless user
        return unless country_code
        return unless ::Gitlab::Saas.feature_available?(:pipl_compliance)
        return unless ::Feature.enabled?(:track_user_access_from_pipl_countries, user)

        access_from_pipl_country = COVERED_COUNTRY_CODES.include?(country_code)

        # If access is from non PIPL-covered country and previous access was not
        # from from a PIPL-covered country (either the user never accessed from
        # PIPL-covered country or their access logs have been reset), there is
        # nothing to do to the user nor their country_access_log records
        return if !access_from_pipl_country && last_access_at.nil?

        return if access_from_pipl_country && tracked_today?

        UpdateUserCountryAccessLogsWorker.perform_async(user.id, country_code)
      end

      private

      attr_reader :user, :country_code

      def tracked_today?
        return false unless last_access_at

        last_access_at.after?(24.hours.ago)
      end

      def last_access_at
        @last_access_at ||= user.last_access_from_pipl_country_at
      end
    end
  end
end
