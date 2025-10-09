# frozen_string_literal: true

module SecretsManagement
  module Helpers
    module UserClientHelper
      include Gitlab::Utils::StrongMemoize

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
end
