# frozen_string_literal: true

module SecretsManagement
  module GroupSecrets
    class ListService < GroupBaseService
      def execute
        return secrets_manager_inactive_response unless group.secrets_manager&.active?

        secrets = user_client.list_secrets(
          group.secrets_manager.ci_secrets_mount_path,
          group.secrets_manager.ci_data_path
        ) do |data|
          metadata = data["metadata"] || {}
          custom_metadata = metadata["custom_metadata"] || {}

          GroupSecret.new(
            name: data["key"],
            group: group,
            description: custom_metadata["description"],
            environment: custom_metadata["environment"],
            protected: custom_metadata["protected"].to_s == 'true',
            metadata_version: metadata["current_metadata_version"],
            create_started_at: metadata["created_time"],
            create_completed_at: custom_metadata["create_completed_at"],
            update_started_at: custom_metadata["update_started_at"],
            update_completed_at: custom_metadata["update_completed_at"]
          )
        end

        ServiceResponse.success(payload: { secrets: secrets })
      end
    end
  end
end
