# frozen_string_literal: true

module Ci
  module Secrets
    class Integration
      PROVIDERS = [
        :azure_key_vault,
        :akeyless,
        :gcp_secret_manager,
        :hashicorp_vault
      ].freeze

      def initialize(variables)
        @variables = variables
      end

      def secrets_provider?
        PROVIDERS.any? { |provider| send(:"#{provider}?") } # rubocop:disable GitlabSecurity/PublicSend -- metaprogramming
      end

      def variable_value(key, default = nil)
        variables_hash.fetch(key, default)
      end

      private

      attr_reader :variables

      def variables_hash
        @variables_hash ||= variables.to_h do |variable|
          [variable[:key], variable[:value]]
        end
      end

      def gcp_secret_manager?
        variable_value('GCP_PROJECT_NUMBER').present? &&
          variable_value('GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID').present? &&
          variable_value('GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID').present?
      end

      def azure_key_vault?
        variable_value('AZURE_KEY_VAULT_SERVER_URL').present? &&
          variable_value('AZURE_CLIENT_ID').present? &&
          variable_value('AZURE_TENANT_ID').present?
      end

      def hashicorp_vault?
        variable_value('VAULT_SERVER_URL').present?
      end

      def akeyless?
        variable_value('AKEYLESS_ACCESS_ID').present?
      end
    end
  end
end
