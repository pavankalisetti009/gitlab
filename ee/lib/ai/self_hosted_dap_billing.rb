# frozen_string_literal: true

module Ai
  module SelfHostedDapBilling
    def self.should_bill?(feature_setting)
      !!(feature_setting&.self_hosted? &&
        self_hosted_dap_billing_enabled?)
    end

    def self.self_hosted_dap_billing_enabled?
      return false if Feature.disabled?(:self_hosted_dap_per_request_billing, :instance)
      # There is no self-hosted billing on gitlab.com instance
      return false if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      # There is no self-hosted billing on offline cloud license. Offline
      # cloud licenses use a different SKU for self-hosted DAP billing.
      return false if ::License.current&.offline_cloud_license?

      true
    end
  end
end
