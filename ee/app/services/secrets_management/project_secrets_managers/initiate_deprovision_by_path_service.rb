# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class InitiateDeprovisionByPathService < BaseInitiateDeprovisionService
      def execute
        result = find_and_validate_secrets_manager!
        return result if result.is_a?(ServiceResponse)

        SecretsManagement::DeprovisionProjectSecretsManagerByPathWorker.perform_async(
          current_user.id,
          result.id,
          params[:namespace_path],
          params[:project_path]
        )

        success_response(result)
      end
    end
  end
end
