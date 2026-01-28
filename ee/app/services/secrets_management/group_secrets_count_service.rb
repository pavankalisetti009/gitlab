# frozen_string_literal: true

module SecretsManagement
  class GroupSecretsCountService < GroupBaseService
    include Concerns::SecretsCountService

    private

    def current_secrets_count
      group_secrets_manager_client.list_secrets(mount_path, data_path).count
    end

    def mount_path
      group.secrets_manager.ci_secrets_mount_path
    end

    def data_path
      group.secrets_manager.ci_data_path
    end
  end
end
