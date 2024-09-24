# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    # Runs several probes to determine whether features connected through Cloud Connector
    # are generally working. This includes checking for availability of certain network
    # endpoints, but also which license is used etc.
    class StatusService
      CUSTOMERS_DOT_URL = ::Gitlab::Routing.url_helpers.subscription_portal_url.freeze
      CLOUD_CONNECTOR_URL = ::CloudConnector::Config.base_url.freeze

      attr_reader :probes

      def initialize(user:, probes: nil)
        @user = user
        @probes = probes || build_default_probes
      end

      def execute
        probe_results = probes.map(&:execute)
        success = probe_results.all?(&:success?)
        payload = { probe_results: probe_results }

        return ServiceResponse.error(message: 'Some probes failed', payload: payload) unless success

        ServiceResponse.success(payload: payload)
      end

      private

      def build_default_probes
        [
          CloudConnector::StatusChecks::Probes::LicenseProbe.new,
          CloudConnector::StatusChecks::Probes::HostProbe.new(CUSTOMERS_DOT_URL),
          CloudConnector::StatusChecks::Probes::HostProbe.new(CLOUD_CONNECTOR_URL),
          CloudConnector::StatusChecks::Probes::AccessProbe.new,
          CloudConnector::StatusChecks::Probes::TokenProbe.new,
          CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
        ]
      end
    end
  end
end
