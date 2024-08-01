# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class AccessProbe < BaseProbe
        def execute(*)
          access_record = CloudConnector::Access.last
          return failure("Access data is missing") unless access_record

          is_stale = (Time.current - access_record.updated_at) > CloudConnector::Access::STALE_PERIOD
          return failure("Access data is stale") if is_stale

          last_token = CloudConnector::ServiceAccessToken.last
          return failure("Access token is missing") unless last_token
          return failure("Access token has expired") if last_token.expired?

          success("Access data is valid")
        end
      end
    end
  end
end
