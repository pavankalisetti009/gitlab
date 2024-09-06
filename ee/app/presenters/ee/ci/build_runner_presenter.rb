# frozen_string_literal: true

module EE
  module Ci
    module BuildRunnerPresenter
      extend ActiveSupport::Concern

      def secrets_configuration
        secrets.to_h.transform_values do |secret|
          secret['vault']['server'] = vault_server(secret) if secret['vault']
          secret['azure_key_vault']['server'] = azure_key_vault_server(secret) if secret['azure_key_vault']
          secret['gcp_secret_manager']['server'] = gcp_secret_manager_server(secret) if secret['gcp_secret_manager']

          if ::Feature.enabled?(:ci_akeyless_secret, project) && (secret['akeyless'])
            secret['akeyless']['server'] = akeyless_server(secret)
          end

          secret
        end
      end

      private

      def vault_server(secret)
        @vault_server ||= {
          'url' => variable_value('VAULT_SERVER_URL'),
          'namespace' => variable_value('VAULT_NAMESPACE'),
          'auth' => {
            'name' => 'jwt',
            'path' => variable_value('VAULT_AUTH_PATH', 'jwt'),
            'data' => {
              'jwt' => vault_jwt(secret),
              'role' => variable_value('VAULT_AUTH_ROLE')
            }.compact
          }
        }
      end

      def vault_jwt(secret)
        if id_tokens?
          id_token_var(secret)
        else
          '${CI_JOB_JWT}'
        end
      end

      def id_token_var(secret)
        secret['token'] || "$#{id_tokens.each_key.first}"
      end

      def gcp_secret_manager_server(secret)
        @gcp_secret_manager_server ||= {
          'project_number' => variable_value('GCP_PROJECT_NUMBER'),
          'workload_identity_federation_pool_id' => variable_value('GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID'),
          'workload_identity_federation_provider_id' => variable_value('GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID'),
          'jwt' => secret['token']
        }
      end

      def akeyless_server(secret)
        @akeyless_server ||= {
          'access_id' => variable_value('AKEYLESS_ACCESS_ID'),
          'access_key' => secret.dig('akeyless', 'akeyless_access_key'),
          'akeyless_api_url' => secret.dig('akeyless', 'akeyless_api_url') || "https://api.akeyless.io",
          'akeyless_access_type' => secret.dig('akeyless', 'akeyless_access_type') || "jwt",
          'akeyless_token' => secret.dig('akeyless', 'akeyless_token') || "",
          'uid_token' => secret.dig('akeyless', 'uid_token') || "",
          'gcp_audience' => secret.dig('akeyless', 'gcp_audience') || "",
          'azure_object_id' => secret.dig('akeyless', 'azure_object_id') || "",
          'k8s_service_account_token' => secret.dig('akeyless', 'k8s_service_account_token') || "",
          'k8s_auth_config_name' => secret.dig('akeyless', 'k8s_auth_config_name') || "",
          'gateway_ca_certificate' => secret.dig('akeyless', 'gateway_ca_certificate') || "",
          'jwt' => secret['token']
        }
      end

      def azure_key_vault_server(secret)
        @azure_key_vault_server ||= {
          'url' => variable_value('AZURE_KEY_VAULT_SERVER_URL'),
          'client_id' => variable_value('AZURE_CLIENT_ID'),
          'tenant_id' => variable_value('AZURE_TENANT_ID'),
          'jwt' => azure_vault_jwt(secret)
        }
      end

      def azure_vault_jwt(secret)
        if id_tokens?
          id_token_var(secret)
        else
          '${CI_JOB_JWT_V2}'
        end
      end
    end
  end
end
