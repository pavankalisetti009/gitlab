# frozen_string_literal: true

module SecretsManagement
  class InitializeProjectSecretsManagerService < BaseService
    def execute
      if project.secrets_manager.nil?
        secrets_manager = ProjectSecretsManager.create!(project: project)

        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      else
        ServiceResponse.error(message: 'Secrets manager already initialized for the project.')
      end
    end
  end
end
