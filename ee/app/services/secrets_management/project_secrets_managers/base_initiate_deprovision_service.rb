# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class BaseInitiateDeprovisionService < ProjectBaseService
      private

      def find_and_validate_secrets_manager!
        secrets_manager = project.secrets_manager

        return ServiceResponse.error(message: 'Secrets manager not found for the project.') unless secrets_manager
        return secrets_manager_inactive_response unless secrets_manager.active?

        secrets_manager.initiate_deprovision!

        secrets_manager
      end

      def success_response(secrets_manager)
        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end
    end
  end
end
