# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class LicenseProbe < BaseProbe
        def execute(*)
          license = License.current
          return failure('No license found') unless license
          return failure('No Online Cloud License found') unless license.online_cloud_license?

          success('Online Cloud License found')
        end
      end
    end
  end
end
