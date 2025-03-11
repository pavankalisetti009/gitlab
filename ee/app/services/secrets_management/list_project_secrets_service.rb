# frozen_string_literal: true

module SecretsManagement
  class ListProjectSecretsService < BaseService
    include SecretsManagerClientHelpers

    def execute
      return inactive_response unless project.secrets_manager&.active?

      secrets = secrets_manager_client.list_secrets(
        project.secrets_manager.ci_secrets_mount_path,
        project.secrets_manager.ci_data_path
      ) do |data|
        custom_metadata = data.dig("metadata", "custom_metadata")

        ProjectSecret.new(
          name: data["key"],
          project: project,
          description: custom_metadata["description"],
          environment: custom_metadata["environment"],
          branch: custom_metadata["branch"]
        )
      end

      ServiceResponse.success(payload: { project_secrets: secrets })
    end

    private

    def inactive_response
      ServiceResponse.error(message: 'Project secrets manager is not active')
    end
  end
end
