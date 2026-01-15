# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class InitiateDeprovisionService < BaseService
      include Helpers::ErrorResponseHelper

      def initialize(secrets_manager, user = nil)
        @secrets_manager = secrets_manager
        @current_user = user
      end

      def execute
        return ServiceResponse.error(message: 'Secrets manager not found for the project.') unless secrets_manager
        return secrets_manager_inactive_response unless secrets_manager.active?

        secrets_manager.initiate_deprovision!

        # Create maintenance task for tracking and recovery
        SecretsManagement::ProjectSecretsManagerMaintenanceTask.create!(
          project_secrets_manager: secrets_manager,
          user: current_user,
          last_processed_at: Time.zone.now,
          action: :deprovision
        )

        SecretsManagement::DeprovisionProjectSecretsManagerWorker.perform_async(
          current_user.id,
          secrets_manager.id
        )

        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      private

      attr_reader :secrets_manager
    end
  end
end
