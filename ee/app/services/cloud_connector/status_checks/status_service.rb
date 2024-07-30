# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    # Runs several probes to determine whether features connected through Cloud Connector
    # are generally working. This includes checking for availability of certain network
    # endpoints, but also which license is used etc.
    class StatusService
      CUSTOMERS_DOT_HOST = URI.parse(::Gitlab::Routing.url_helpers.subscription_portal_url).host.freeze
      CLOUD_CONNECTOR_HOST = URI.parse(::CloudConnector::Config.base_url).host.freeze
      DEFAULT_PROBES = [
        CloudConnector::StatusChecks::Probes::LicenseProbe.new,
        CloudConnector::StatusChecks::Probes::HostProbe.new(CUSTOMERS_DOT_HOST, 443),
        CloudConnector::StatusChecks::Probes::HostProbe.new(CLOUD_CONNECTOR_HOST, 443),
        CloudConnector::StatusChecks::Probes::EndToEndProbe.new
      ].freeze

      def initialize(user:, probes: DEFAULT_PROBES)
        @user = user
        @probes = probes
      end

      def execute
        execution_context = { user: @user }
        probe_results = @probes.map { |probe| probe.execute(**execution_context) }
        success = probe_results.all?(&:success?)
        payload = { probe_results: probe_results }

        return ServiceResponse.error(message: 'Some probes failed', payload: payload) unless success

        ServiceResponse.success(payload: payload)
      end
    end
  end
end
