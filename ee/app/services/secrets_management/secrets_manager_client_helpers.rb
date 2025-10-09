# frozen_string_literal: true

module SecretsManagement
  module SecretsManagerClientHelpers
    include Gitlab::Utils::StrongMemoize

    def global_secrets_manager_client
      jwt = SecretsManagerJwt.new(
        current_user: current_user,
        project: project
      ).encoded

      SecretsManagerClient.new(jwt: jwt)
    end
    strong_memoize_attr :global_secrets_manager_client

    def namespace_secrets_manager_client
      project_secrets_manager = SecretsManagement::ProjectSecretsManager.find_by_project_id(project.id)
      global_secrets_manager_client.with_namespace(project_secrets_manager.namespace_path)
    end
    strong_memoize_attr :namespace_secrets_manager_client

    def project_secrets_manager_client
      project_secrets_manager = SecretsManagement::ProjectSecretsManager.find_by_project_id(project.id)
      global_secrets_manager_client.with_namespace(project_secrets_manager.full_project_namespace_path)
    end
    strong_memoize_attr :project_secrets_manager_client
  end
end
