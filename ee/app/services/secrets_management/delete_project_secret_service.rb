# frozen_string_literal: true

module SecretsManagement
  class DeleteProjectSecretService < BaseService
    include SecretsManagerClientHelpers

    def execute(name)
      return inactive_response unless project.secrets_manager&.active?

      read_service = ReadProjectSecretService.new(project, current_user)
      read_result = read_service.execute(name)

      return read_result unless read_result.success?

      project_secret = read_result.payload[:project_secret]

      # Delete the secret
      secrets_manager_client.delete_kv_secret(
        project.secrets_manager.ci_secrets_mount_path,
        project.secrets_manager.ci_data_path(name)
      )

      policy_name = project.secrets_manager.ci_policy_name(
        project_secret.environment,
        project_secret.branch
      )

      # Process information about remaining secrets in a single pass
      has_shared_policy, wildcard_secrets = process_remaining_secrets(policy_name)

      if has_shared_policy
        # Other secrets use this policy, just remove this specific secret's path
        remove_secret_from_policy(policy_name, name)
      else
        # No other secrets use this policy, delete it
        delete_policy(policy_name)
      end

      # Update JWT role glob policies if we've deleted a secret with wildcards
      if project_secret.environment.include?('*') || project_secret.branch.include?('*')
        update_jwt_role_glob_policies(wildcard_secrets)
      end

      ServiceResponse.success(payload: { project_secret: project_secret })
    end

    private

    def process_remaining_secrets(policy_name)
      has_shared_policy = false
      wildcard_secrets = []

      # Fetch and process all secrets in a single pass
      all_secrets = secrets_manager_client.list_secrets(
        project.secrets_manager.ci_secrets_mount_path,
        project.secrets_manager.ci_data_root_path
      )

      all_secrets.each do |secret|
        metadata = secret['metadata']
        next unless metadata

        secret_env = metadata.dig('custom_metadata', 'environment')
        secret_branch = metadata.dig('custom_metadata', 'branch')
        next unless secret_env && secret_branch

        unless has_shared_policy
          secret_policy_name = project.secrets_manager.ci_policy_name(secret_env, secret_branch)
          has_shared_policy = true if secret_policy_name == policy_name
        end

        wildcard_secrets << secret if secret_env.include?('*') || secret_branch.include?('*')
      end

      [has_shared_policy, wildcard_secrets]
    end

    def remove_secret_from_policy(policy_name, secret_name)
      policy = secrets_manager_client.get_policy(policy_name)

      secret_path = project.secrets_manager.ci_full_path(secret_name)
      metadata_path = project.secrets_manager.ci_metadata_full_path(secret_name)

      policy.remove_capability(secret_path, "read")
      policy.remove_capability(metadata_path, "read")

      secrets_manager_client.set_policy(policy)
    end

    def delete_policy(policy_name)
      secrets_manager_client.delete_policy(policy_name)
    end

    def update_jwt_role_glob_policies(wildcard_secrets)
      role = secrets_manager_client.read_jwt_role(
        project.secrets_manager.ci_auth_mount,
        project.secrets_manager.ci_auth_role
      )

      # Start with the literal policies that should always be present
      updated_policies = Set.new(project.secrets_manager.ci_auth_literal_policies)

      # Add all glob policies needed by remaining wildcard secrets
      wildcard_secrets.each do |secret|
        env = secret.dig('metadata', 'custom_metadata', 'environment')
        branch = secret.dig('metadata', 'custom_metadata', 'branch')

        glob_policies = project.secrets_manager.ci_auth_glob_policies(env, branch)
        updated_policies.merge(glob_policies)
      end

      # Update the JWT role with the rebuilt policies
      role['token_policies'] = updated_policies.to_a
      secrets_manager_client.update_jwt_role(
        project.secrets_manager.ci_auth_mount,
        project.secrets_manager.ci_auth_role,
        **role
      )
    end

    def inactive_response
      ServiceResponse.error(message: 'Project secrets manager is not active')
    end
  end
end
