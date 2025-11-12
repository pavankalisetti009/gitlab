# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class InitiateDeprovisionService < ProjectBaseService
      def execute
        secrets_manager = project.secrets_manager

        return ServiceResponse.error(message: 'Secrets manager not found for the project.') unless secrets_manager
        return ServiceResponse.error(message: 'Secrets manager is not active.') unless secrets_manager.active?

        secrets_manager.initiate_deprovision!

        SecretsManagement::DeprovisionProjectSecretsManagerWorker.perform_async(
          current_user.id,
          secrets_manager.id
        )

        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end
    end
  end
end
