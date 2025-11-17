# frozen_string_literal: true

module SecretsManagement
  module GroupSecretsManagers
    class DeprovisionService < GroupBaseService
      MAX_NAMESPACE_STATUS_POLL_ATTEMPTS = 20
      POLL_SLEEP_INTERVAL = 0.1.seconds

      def initialize(secrets_manager, current_user)
        super(secrets_manager.group, current_user)

        @secrets_manager = secrets_manager
      end

      def execute
        with_exclusive_lease_for(group, lease_timeout: 120.seconds.to_i) do
          execute_deprovision
        end
      end

      private

      attr_reader :secrets_manager

      def execute_deprovision
        # Namespaces can only be disabled if the namespace is empty of child
        # namespaces. As we do not populate child namespaces entries under the
        # group namespace, we will always be able to delete it, thus cleaning
        # up all data contained within it. However, removal of the group's
        # root namespace will only happen if there's no path.

        # Deleting a namespace takes time.

        MAX_NAMESPACE_STATUS_POLL_ATTEMPTS.times do |n|
          result = namespace_secrets_manager_client.disable_namespace(secrets_manager.group_path)
          if result.key?("data") && !result["data"].nil? &&
              result["data"].key?("status") && !result["data"]["status"].nil? &&
              result["data"]["status"] == "in-progress"
            sleep POLL_SLEEP_INTERVAL * n
            next
          end

          break
        end

        # Lazily delete the parent namespace; we don't care if it happens right
        # away as this would only cause a subsequent enable to fail with an
        # error if it is in the same parent namespace. As we're already in a
        # worker, this will be asynchronous from the API handler with no way
        # to exclude these two from executing at the same time anyways.
        begin
          global_secrets_manager_client.disable_namespace(secrets_manager.root_namespace_path)
        rescue SecretsManagement::SecretsManagerClient::ApiError => e
          raise e unless e.message.include? 'containing child namespaces'
        end

        # Finally destroy our database record.
        delete_secrets_manager

        ServiceResponse.success(payload: { group_secrets_manager: secrets_manager })
      end

      def delete_secrets_manager
        secrets_manager.destroy!
      end
    end
  end
end
