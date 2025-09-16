# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class DeprovisionService < BaseService
      include SecretsManagerClientHelpers

      def initialize(secrets_manager, current_user)
        super(secrets_manager.project, current_user)

        @secrets_manager = secrets_manager
      end

      def execute
        # All OpenBao client methods used here are idempotent:
        # - delete_jwt_role: returns nil if role doesn't exist
        # - delete_policy: has optional: true, doesn't error if missing
        # - disable_secrets_engine: doesn't error if mount doesn't exist
        # This makes the entire service idempotent and safe for retries
        delete_jwt_roles
        delete_policies
        delete_secrets_engine
        delete_secrets_manager
        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      private

      attr_reader :secrets_manager

      def delete_jwt_roles
        # Delete JWT roles only - auth mounts are shared per namespace
        # so we don't delete them when deprovisioning a single project
        secrets_manager_client.delete_jwt_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role
        )

        # TODO: This is temporary, we just add this here to simulate left-over jwt non-CEL role in production
        # that needs to be cleaned up when running this service. In the next milestone, let's remove
        # this and related code in the service. Expectation is that user auth mounts will only have CEL role.
        secrets_manager_client.delete_jwt_role(
          secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role
        )

        secrets_manager_client.delete_jwt_cel_role(
          secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role
        )
      end

      def delete_policies
        # Delete all policies that belong to this project
        # Using list_project_policies without type to get ALL policies
        secrets_manager_client.list_project_policies(project_id: project.id).each do |policy_data|
          secrets_manager_client.delete_policy(policy_data["key"])
        end
      end

      def delete_secrets_engine
        secrets_manager_client.disable_secrets_engine(secrets_manager.ci_secrets_mount_path)
      end

      def delete_secrets_manager
        secrets_manager.destroy!
      end
    end
  end
end
