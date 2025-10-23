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
          secret['aws_secrets_manager']['server'] = aws_secrets_manager_server(secret) if secret['aws_secrets_manager']
          secret['gitlab_secrets_manager'] = gitlab_secrets_manager_payload(secret) if secret['gitlab_secrets_manager']

          secret
        end
      end

      def policy_options
        policy_options = options[:policy]

        # New structure
        if policy_options.present?
          {
            execution_policy_job: true,
            policy_name: policy_options[:name],
            policy_variables_override_allowed: policy_options.dig(:variables_override, :allowed),
            policy_variables_override_exceptions: policy_options.dig(:variables_override,
              :exceptions).presence
          }.compact
        # Old structure for backwards compatibility: https://gitlab.com/gitlab-org/gitlab/-/issues/577272
        elsif options[:execution_policy_job]
          {
            execution_policy_job: true,
            policy_name: options[:execution_policy_name],
            policy_variables_override_allowed: options.dig(:execution_policy_variables_override, :allowed),
            policy_variables_override_exceptions: options.dig(:execution_policy_variables_override,
              :exceptions).presence
          }
        end
      end

      private

      def vault_server(secret)
        @vault_server ||= {
          'url' => variables['VAULT_SERVER_URL']&.value,
          'namespace' => variables['VAULT_NAMESPACE']&.value,
          'auth' => {
            'name' => 'jwt',
            'path' => variables['VAULT_AUTH_PATH']&.value || 'jwt',
            'data' => {
              'jwt' => vault_jwt(secret),
              'role' => variables['VAULT_AUTH_ROLE']&.value
            }.compact
          }
        }
      end

      def aws_secrets_manager_server(secret)
        @aws_secrets_manager_server ||= {
          'region' => variables['AWS_REGION']&.value,
          'jwt' => aws_token(secret),
          'role_arn' => variables['AWS_ROLE_ARN']&.value,
          'role_session_name' => variables['AWS_ROLE_SESSION_NAME']&.value
        }
      end

      def gitlab_secrets_manager_server(project_secrets_manager)
        @gitlab_secrets_manager_server ||= {
          'url' => SecretsManagement::ProjectSecretsManager.server_url,
          'inline_auth' => {
            'jwt' => project_secrets_manager.ci_jwt(self),
            'role' => project_secrets_manager.ci_auth_role,
            'auth_mount' => project_secrets_manager.ci_auth_mount
          }.compact
        }
      end

      def gitlab_secrets_manager_payload(secret)
        secret_name = secret['gitlab_secrets_manager']['name']
        project_secrets_manager = SecretsManagement::ProjectSecretsManager.find_by_project_id(project.id)
        {
          'engine' => { 'name' => "kv-v2", 'path' => project_secrets_manager.ci_secrets_mount_path },
          'path' => project_secrets_manager.ci_data_path(secret_name),
          'field' => "value",
          'server' => gitlab_secrets_manager_server(project_secrets_manager)
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

      def aws_token(secret)
        secret['token'] || '$AWS_ID_TOKEN'
      end

      def gcp_secret_manager_server(secret)
        @gcp_secret_manager_server ||= {
          'project_number' => variables['GCP_PROJECT_NUMBER']&.value,
          'workload_identity_federation_pool_id' => variables['GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID']&.value,
          'workload_identity_federation_provider_id' =>
            variables['GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID']&.value,
          'jwt' => secret['token']
        }
      end

      def azure_key_vault_server(secret)
        @azure_key_vault_server ||= {
          'url' => variables['AZURE_KEY_VAULT_SERVER_URL']&.value,
          'client_id' => variables['AZURE_CLIENT_ID']&.value,
          'tenant_id' => variables['AZURE_TENANT_ID']&.value,
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
