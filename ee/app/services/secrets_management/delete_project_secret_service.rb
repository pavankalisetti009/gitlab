# frozen_string_literal: true

module SecretsManagement
  class DeleteProjectSecretService < BaseService
    include SecretsManagerClientHelpers
    include SecretCiPoliciesRefresherHelper

    def execute(name)
      return inactive_response unless secrets_manager&.active?

      read_service = ReadProjectSecretService.new(project, current_user)
      read_result = read_service.execute(name)

      return read_result unless read_result.success?

      project_secret = read_result.payload[:project_secret]

      # Delete the secret
      secrets_manager_client.delete_kv_secret(
        secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(name)
      )

      refresh_secret_ci_policies(project_secret, delete: true)

      ServiceResponse.success(payload: { project_secret: project_secret })
    end

    private

    delegate :secrets_manager, to: :project

    def inactive_response
      ServiceResponse.error(message: 'Project secrets manager is not active')
    end
  end
end
