# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class InitializeService < ProjectBaseService
      def execute
        if project.secrets_manager.nil?
          secrets_manager = ProjectSecretsManager.create!(project: project)

          SecretsManagement::ProvisionProjectSecretsManagerWorker.perform_async(
            current_user.id,
            secrets_manager.id
          )

          ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
        else
          ServiceResponse.error(message: 'Secrets manager already initialized for the project.')
        end
      end
    end
  end
end
