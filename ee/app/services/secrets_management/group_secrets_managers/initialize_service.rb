# frozen_string_literal: true

module SecretsManagement
  module GroupSecretsManagers
    class InitializeService < GroupBaseService
      def execute
        if group.secrets_manager.nil?
          secrets_manager = GroupSecretsManager.create!(group: group)

          SecretsManagement::ProvisionGroupSecretsManagerWorker.perform_async(
            current_user.id,
            secrets_manager.id
          )

          ServiceResponse.success(payload: { group_secrets_manager: secrets_manager })
        else
          ServiceResponse.error(message: 'Secrets manager already initialized for the group.')
        end
      end
    end
  end
end
