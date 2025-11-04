# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class DeleteService < BaseService
      include SecretsManagerClientHelpers
      include CiPolicies::SecretRefresherHelper
      include Helpers::UserClientHelper
      include Helpers::ExclusiveLeaseHelper
      include ErrorResponseHelper

      def execute(name)
        with_exclusive_lease_for(project) do
          execute_secret_deletion(name)
        end
      end

      private

      delegate :secrets_manager, to: :project

      def execute_secret_deletion(name)
        return inactive_response unless secrets_manager&.active?

        read_service = ProjectSecrets::ReadService.new(project, current_user)
        read_result = read_service.execute(name)

        return read_result unless read_result.success?

        project_secret = read_result.payload[:project_secret]

        # Delete the secret
        user_client.delete_kv_secret(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name)
        )

        refresh_secret_ci_policies(project_secret, delete: true)

        ServiceResponse.success(payload: { project_secret: project_secret })
      end
    end
  end
end
