# frozen_string_literal: true

module SecretsManagement
  class UpdateProjectSecretService < BaseService
    include Gitlab::Utils::StrongMemoize
    include SecretsManagerClientHelpers
    include SecretCiPoliciesRefresherHelper

    # NOTE: There is a potential race condition with secret updates because OpenBao
    # currently doesn't support versioning for metadata operations. This means that
    # concurrent metadata-only updates may overwrite each other without warning.
    #
    # When updating the value, OpenBao does support check-and-set (CAS) versioning,
    # but we're not currently using it since we can't ensure the same protection for
    # metadata-only updates, which would create inconsistent behavior.
    #
    # Future versions of OpenBao are expected to add versioning support for metadata
    # operations, at which point we should implement optimistic concurrency control
    # for all update operations.
    def execute(name:, value: nil, description: nil, environment: nil, branch: nil)
      return inactive_response unless project.secrets_manager&.active?

      read_service = ReadProjectSecretService.new(project, current_user)
      read_result = read_service.execute(name)

      return read_result unless read_result.success?

      project_secret = read_result.payload[:project_secret]

      project_secret.description = description unless description.nil?
      project_secret.environment = environment unless environment.nil?
      project_secret.branch = branch unless branch.nil?

      # Update the secret
      update_secret(project_secret, value)
    end

    private

    delegate :secrets_manager, to: :project

    def update_secret(project_secret, value)
      return error_response(project_secret) unless project_secret.valid?

      custom_metadata = {
        environment: project_secret.environment,
        branch: project_secret.branch,
        description: project_secret.description
      }.compact

      # NOTE: The current implementation makes two separate API calls (one for the value, one for metadata).
      # In the future, the secret value update will be handled directly in the frontend for better security,
      # before calling this service. However, the metadata update and policy management will still be handled
      # in this Rails backend service, as they contain essential information for access control.

      if value
        secrets_manager_client.update_kv_secret(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          value
        )
      end

      secrets_manager_client.update_kv_secret_metadata(
        secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(project_secret.name),
        custom_metadata
      )

      refresh_secret_ci_policies(project_secret)

      ServiceResponse.success(payload: { project_secret: project_secret })
    end

    def error_response(project_secret)
      ServiceResponse.error(
        message: project_secret.errors.full_messages.to_sentence,
        payload: { project_secret: project_secret }
      )
    end

    def inactive_response
      ServiceResponse.error(message: 'Project secrets manager is not active')
    end
  end
end
