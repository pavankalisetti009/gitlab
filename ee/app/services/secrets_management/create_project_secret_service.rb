# frozen_string_literal: true

module SecretsManagement
  class CreateProjectSecretService < BaseService
    include Gitlab::Utils::StrongMemoize
    include SecretsManagerClientHelpers

    # MAX_SECRET_SIZE sets the maximum size of a secret value; see note
    # below before removing.
    MAX_SECRET_SIZE = 10000

    def execute(name:, value:, environment:, branch:, description: nil)
      project_secret = ProjectSecret.new(
        name: name,
        description: description,
        project: project,
        branch: branch,
        environment: environment
      )

      store_secret(project_secret, value)
    end

    private

    delegate :secrets_manager, to: :project

    def store_secret(project_secret, value)
      return error_response(project_secret) unless project_secret.valid?

      # Before removing value from the above and sending value directly
      # to OpenBao, ensure it has been updated with request parameter
      # size limiting quotas.
      if value.bytesize > MAX_SECRET_SIZE
        project_secret.errors.add(:base, "Length of project secret value exceeds allowed limits (10k bytes).")
        return error_response(project_secret)
      end

      # The follow API calls are ordered such that they fail closed: first we
      # create the secret and its metadata and then attach policy to it. If we
      # fail to attach policy, no pipelines can access it and only project-level
      # users can modify it in the future. Updating a secret to set missing
      # branch and environments will then allow pipelines to access the secret.

      create_secret(project_secret, value)
      add_policy(project_secret)
      add_wildcard_role(project_secret) if has_glob_patterns?(project_secret)

      ServiceResponse.success(payload: { project_secret: project_secret })
    rescue SecretsManagerClient::ApiError => e
      raise e unless e.message.include?('check-and-set parameter did not match the current version')

      project_secret.errors.add(:base, 'Project secret already exists.')
      error_response(project_secret)
    end

    def create_secret(project_secret, value)
      # Create the secret itself.
      custom_metadata = {
        environment: project_secret.environment,
        branch: project_secret.branch,
        description: project_secret.description
      }.compact

      secrets_manager_client.update_kv_secret(
        secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(project_secret.name),
        value,
        custom_metadata
      )
    end

    def add_policy(project_secret)
      # Add it to the CI policy for the specified environment and branch.
      policy_name = secrets_manager.ci_policy_name(
        project_secret.environment,
        project_secret.branch
      )

      policy = secrets_manager_client.get_policy(policy_name)
      policy.add_capability(
        secrets_manager.ci_full_path(project_secret.name),
        "read"
      )
      policy.add_capability(
        secrets_manager.ci_metadata_full_path(project_secret.name),
        "read"
      )
      secrets_manager_client.set_policy(policy)
    end

    def add_wildcard_role(project_secret)
      # Lastly, update the JWT role. If we have a glob, we need to know
      # the possible values for that glob so that we can.
      role = secrets_manager_client.read_jwt_role(
        secrets_manager.ci_auth_mount,
        secrets_manager.ci_auth_role
      )

      token_policies = Set.new(role["token_policies"])
      new_policies = secrets_manager.ci_auth_glob_policies(
        project_secret.environment,
        project_secret.branch
      )
      token_policies.merge(new_policies)

      role["token_policies"] = token_policies.to_a
      secrets_manager_client.update_jwt_role(
        secrets_manager.ci_auth_mount,
        secrets_manager.ci_auth_role,
        **role
      )
    end

    def has_glob_patterns?(project_secret)
      project_secret.environment.include?("*") || project_secret.branch.include?("*")
    end

    def error_response(project_secret)
      ServiceResponse.error(
        message: project_secret.errors.full_messages.to_sentence,
        payload: { project_secret: project_secret }
      )
    end
  end
end
