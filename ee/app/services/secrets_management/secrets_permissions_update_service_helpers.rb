# frozen_string_literal: true

module SecretsManagement
  module SecretsPermissionsUpdateServiceHelpers
    extend ActiveSupport::Concern

    INTERNAL_PERMISSIONS = %w[list scan].freeze

    def execute(principal_id:, principal_type:, permissions:, expired_at:)
      with_exclusive_lease_for(resource) do
        execute_update_permission(
          principal_id: principal_id,
          principal_type: principal_type,
          permissions: permissions,
          expired_at: expired_at
        )
      end
    end

    private

    delegate :secrets_manager, to: :resource

    def execute_update_permission(principal_id:, principal_type:, permissions:, expired_at:)
      secrets_permission = permission_class.new(
        principal_id: principal_id,
        principal_type: principal_type,
        permissions: permissions,
        granted_by: current_user.id,
        expired_at: expired_at,
        resource: resource
      )

      store_permission(secrets_permission)
    end

    def store_permission(secrets_permission)
      return error_response(secrets_permission) unless secrets_permission.valid?

      secrets_permission.permissions = secrets_permission.permissions + INTERNAL_PERMISSIONS

      # Get or create policy
      policy_name = secrets_permission.secrets_manager.policy_name_for_principal(
        principal_type: secrets_permission.principal_type,
        principal_id: secrets_permission.principal_id
      )

      policy = client.get_policy(policy_name)

      # If policy doesn't exist, create a new one
      policy ||= AclPolicy.new(policy_name)

      # Add or update paths with permissions
      update_policy_paths(
        policy,
        secrets_permission.secrets_manager,
        secrets_permission.permissions,
        secrets_permission.normalized_expired_at
      )

      # Save the policy to OpenBao
      client.set_policy(policy)

      # the list permission is only used internally and should not be returned to the user
      secrets_permission.permissions = secrets_permission.permissions - INTERNAL_PERMISSIONS

      ServiceResponse.success(payload: { secrets_permission: secrets_permission })
    rescue SecretsManagement::SecretsManagerClient::ApiError => e
      raise e unless e.message.include?('check-and-set parameter did not match the current version')

      secrets_permission.errors.add(:base, "Failed to save secrets_permission: #{e.message}")
      error_response(secrets_permission)
    end

    def update_policy_paths(policy, secrets_manager, permissions, expired_at)
      data_path = secrets_manager.ci_full_path('*')
      metadata_path = secrets_manager.ci_metadata_full_path('*')
      detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

      # Clear existing capabilities for these paths
      policy.paths[data_path].capabilities.clear if policy.paths[data_path]
      policy.paths[metadata_path].capabilities.clear if policy.paths[metadata_path]
      policy.paths[detailed_metadata_path].capabilities.clear if policy.paths[detailed_metadata_path]

      # Add new capabilities
      permissions.each do |permission|
        policy.add_capability(data_path, permission, user: current_user) if permission != 'read'
        policy.add_capability(metadata_path, permission, user: current_user)
      end
      policy.add_capability(detailed_metadata_path, 'list', user: current_user)

      policy.paths[data_path].expired_at = expired_at
      policy.paths[metadata_path].expired_at = expired_at
      policy.paths[detailed_metadata_path].expired_at = expired_at
    end

    def error_response(secrets_permission)
      ServiceResponse.error(
        message: secrets_permission.errors.full_messages.to_sentence,
        payload: { secrets_permission: secrets_permission }
      )
    end
  end
end
