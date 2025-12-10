# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class DeprovisionService < ProjectBaseService
      # secrets_manager may be nil because the project deletion removes it via DB CASCADE.
      # Deprovisioning must still finish, so we fallback to namespace_path/project_path.
      def initialize(secrets_manager, current_user, namespace_path: nil, project_path: nil)
        super(secrets_manager&.project, current_user)

        @secrets_manager = secrets_manager
        # Namespace and project paths may be passed explicitly instead of deriving them from secrets_manager.
        # This is needed to handle cases where secrets already exist without an associated secrets_manager.
        @namespace_path = namespace_path || secrets_manager&.namespace_path
        @project_path   = project_path || secrets_manager&.project_path
      end

      def execute
        acquire_lease_if_needed do
          execute_deprovision
        end
      end

      def namespace_secrets_manager_client
        global_secrets_manager_client.with_namespace(namespace_path)
      end

      def project_secrets_manager_client
        global_secrets_manager_client.with_namespace([namespace_path, project_path].compact.join('/'))
      end

      def legacy_cleanup
        # This performs legacy pre-namespace cleanup.
        #
        # All OpenBao client methods used here are idempotent:
        # - delete_jwt_role: returns nil if role doesn't exist
        # - delete_policy: has optional: true, doesn't error if missing
        # - disable_secrets_engine: doesn't error if mount doesn't exist
        # This makes the entire service idempotent and safe for retries
        delete_policies
        delete_auth_engine
        delete_secrets_engine
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        raise e unelss e.message.include? 'route entry not found'
      end

      private

      attr_reader :secrets_manager, :namespace_path, :project_path

      def acquire_lease_if_needed(&block)
        return yield if secrets_manager.nil?

        with_exclusive_lease_for(project, lease_timeout: 120.seconds.to_i, &block)
      end

      def execute_deprovision
        # Namespaces can only be disabled if the namespace is empty of child
        # namespaces. As we do not populate child namespaces entries under the
        # project namespace, we will always be able to delete it, thus cleaning
        # up all data contained within it. However, removal of the project's
        # namespace namespace will only happen if there's no path.

        # Deleting a namespace takes time.
        begin
          20.times do |n|
            result = namespace_secrets_manager_client.disable_namespace(project_path)
            if result.key?("data") && !result["data"].nil? &&
                result["data"].key?("status") && !result["data"]["status"].nil? &&
                result["data"]["status"] == "in-progress"
              sleep 0.1 * n
              next
            end

            break
          end
        rescue SecretsManagement::SecretsManagerClient::ApiError => e
          # This error occurs when the namespace has not been created yet;
          # this would occur when deprovisioning a legacy project.
          raise e unless e.message.include? 'route entry not found'
        end

        # Lazily delete this namespace; we don't care if it happens right
        # away as this would only cause a subsequent enable to fail with an
        # error if it is in the same parent namespace. As we're already in a
        # worker, this will be asynchronous from the API handler with no way
        # to exclude these two from executing at the same time anyways.
        begin
          global_secrets_manager_client.disable_namespace(namespace_path)
        rescue SecretsManagement::SecretsManagerClient::ApiError => e
          raise e unless e.message.include? 'containing child namespaces'
        end

        # Finally destroy our database record.
        delete_secrets_manager

        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      def delete_secrets_manager
        secrets_manager&.destroy!
      end
    end
  end
end
