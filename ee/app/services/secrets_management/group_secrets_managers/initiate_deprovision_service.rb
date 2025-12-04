# frozen_string_literal: true

module SecretsManagement
  module GroupSecretsManagers
    class InitiateDeprovisionService < GroupBaseService
      def execute
        secrets_manager = group.secrets_manager

        return ServiceResponse.error(message: 'Secrets manager not found for the group.') unless secrets_manager
        return secrets_manager_inactive_response unless secrets_manager.active?

        secrets_manager.initiate_deprovision!

        SecretsManagement::DeprovisionGroupSecretsManagerWorker.perform_async(
          current_user.id,
          secrets_manager.id
        )

        ServiceResponse.success(payload: { group_secrets_manager: secrets_manager })
      end
    end
  end
end
