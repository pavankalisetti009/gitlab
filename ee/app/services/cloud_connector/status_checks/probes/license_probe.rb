# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class LicenseProbe < BaseProbe
        def execute(*)
          license = License.current
          return failure(missing_license_text) unless license
          return failure(wrong_license_text) unless license.online_cloud_license?

          success('Subscription can be synchronized.')
        end

        private

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
