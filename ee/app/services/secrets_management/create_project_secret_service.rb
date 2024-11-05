# frozen_string_literal: true

module SecretsManagement
  class CreateProjectSecretService < BaseService
    include Gitlab::Utils::StrongMemoize

    def execute(name:, value:, description: nil)
      if secrets_manager&.active?
        create_project_secret(name, value, description)
      else
        ServiceResponse.error(message: 'Project secrets manager is not active.')
      end
    end

    private

    def secrets_manager
      project.secrets_manager
    end
    strong_memoize_attr(:secrets_manager)

    def create_project_secret(name, value, description)
      custom_metadata = { description: description } if description

      client = SecretsManagerClient.new
      client.create_kv_secret(
        secrets_manager.ci_secrets_mount_path,
        name,
        value,
        custom_metadata
      )

      project_secret = ProjectSecret.new(name: name, description: description, project: project)
      ServiceResponse.success(payload: { project_secret: project_secret })
    rescue SecretsManagerClient::ApiError => e
      raise e unless e.message.include?('check-and-set parameter did not match the current version')

      ServiceResponse.error(message: 'Project secret already exists.')
    end
  end
end
