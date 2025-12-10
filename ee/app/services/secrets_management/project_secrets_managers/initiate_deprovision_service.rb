# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class InitiateDeprovisionService < BaseInitiateDeprovisionService
      def execute
        result = find_and_validate_secrets_manager!
        return result if result.is_a?(ServiceResponse)

        SecretsManagement::DeprovisionProjectSecretsManagerWorker.perform_async(
          current_user.id,
          result.id
        )

        success_response(result)
      end
    end
  end
end
