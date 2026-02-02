# frozen_string_literal: true

module SecretsManagement
  class ProjectBaseService < BaseService
    include Gitlab::Utils::StrongMemoize
    include Helpers::ExclusiveLeaseHelper
    include Helpers::ErrorResponseHelper

    def global_secrets_manager_client
      jwt = SecretsManagerJwt.new(
        current_user: current_user,
        project: project
      ).encoded

      SecretsManagerClient.new(jwt: jwt)
    end
    strong_memoize_attr :global_secrets_manager_client

    def namespace_secrets_manager_client
      global_secrets_manager_client.with_namespace(project.secrets_manager.namespace_path)
    end
    strong_memoize_attr :namespace_secrets_manager_client

    def project_secrets_manager_client
      global_secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
    end
    strong_memoize_attr :project_secrets_manager_client

    def user_client
      user_jwt = UserJwt.new(
        current_user: current_user,
        project: project
      ).encoded

      SecretsManagerClient.new(
        jwt: user_jwt, role: project.secrets_manager.user_auth_role,
        auth_namespace: project.secrets_manager.full_project_namespace_path,
        auth_mount: project.secrets_manager.user_auth_mount,
        namespace: project.secrets_manager.full_project_namespace_path,
        use_cel_auth: true)
    end
    strong_memoize_attr :user_client
  end
end
