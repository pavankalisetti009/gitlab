# frozen_string_literal: true

module SecretsManagement
  class DeprovisionProjectSecretsManagerByPathWorker
    include ApplicationWorker

    data_consistency :sticky

    urgency :high

    idempotent!

    feature_category :secrets_management

    def perform(current_user_id, project_secrets_manager_id, namespace_path, project_path)
      user = User.find_by_id(current_user_id)
      return unless user

      secrets_manager = ProjectSecretsManager.find_by_id(project_secrets_manager_id)

      ProjectSecretsManagers::DeprovisionService.new(
        secrets_manager,
        user,
        namespace_path: namespace_path,
        project_path: project_path
      ).execute
    end
  end
end
