# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class DeprovisionService < ProjectBaseService
      def initialize(secrets_manager, current_user)
        super

        @secrets_manager = secrets_manager
        @project = secrets_manager.project
        @namespace_path = secrets_manager.namespace_path || build_namespace_path
        @project_path = secrets_manager.project_path || build_project_path
      end

      def execute
        acquire_lease_if_needed do
          execute_deprovision
        end
      end

      private

      attr_reader :secrets_manager, :namespace_path, :project_path, :project

      def build_namespace_path
        [project.namespace.type.downcase, project.namespace.id.to_s].join('_')
      end

      def build_project_path
        "project_#{project.id}"
      end

      def namespace_secrets_manager_client
        global_secrets_manager_client.with_namespace(namespace_path)
      end

      def acquire_lease_if_needed(&block)
        return yield if project.nil?

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
