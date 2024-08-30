# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class LicenseProbe < BaseProbe
        extend ::Gitlab::Utils::Override

        validate :check_license_exists
        validate :check_license_valid

        after_validation :collect_license_details

        private

        def license
          @license ||= License.current
        end

        override :success_message
        def success_message
          _('Subscription can be synchronized.')
        end

        def check_license_exists
          errors.add(:base, missing_license_text) unless license
        end

        def check_license_valid
          return unless license
          return if license.online_cloud_license?

          errors.add(:base, wrong_license_text)
        end

        def collect_license_details
          return unless license

          details.add(:plan, license.plan)
          details.add(:trial, license.trial?)
          details.add(:expires_at, license.expires_at)
          details.add(:grace_period_expired, license.grace_period_expired?)
          details.add(:online_cloud_license, license.online_cloud_license?)
        end

        def missing_license_text
          _("Subscription for this instance cannot be synchronized. " \
            "Contact GitLab customer support to obtain a license.")
        end

        def wrong_license_text
          _("Subscription for this instance cannot be synchronized. " \
            "Contact GitLab customer support to upgrade your license.")
        end
      end
    end
  end
end
