# frozen_string_literal: true

module SecretsManagement
  module SecretsPermissions
    module ListServiceHelpers
      extend ActiveSupport::Concern

      def execute
        return secrets_manager_inactive_response unless resource.secrets_manager&.active?

        secrets_permissions = list_secrets_permissions(resource)

        ServiceResponse.success(payload: { secrets_permissions: secrets_permissions })
      end

      private

      delegate :secrets_manager, to: :resource

      def list_secrets_permissions(resource)
        permissions = []

        client.list_policies(type: :users) do |policy_data|
          policy_name = policy_data["key"]
          policy = policy_data["metadata"]

          # Extract principal information from policy name
          path_parts = policy_name.split('/')
          principal_type, principal_id = extract_principal_info_from_policy(path_parts)

          next unless principal_type && principal_id

          granted_by = nil
          expired_at = nil
          # Extract capabilities from the policy
          capabilities_set = Set.new

          policy.paths.each_value do |path_obj|
            granted_by = path_obj.granted_by
            expired_at = path_obj.expired_at
            path_obj.capabilities.each do |capability|
              if SecretsManagement::BaseSecretsPermission::VALID_CAPABILITIES.include?(capability)
                capabilities_set.add(capability)
              end
            end
          end

          # Create the permission object and set actions from capabilities
          permission = permission_class.new(
            resource: resource,
            principal_type: principal_type,
            principal_id: principal_id,
            granted_by: granted_by,
            expired_at: expired_at
          )
          permission.set_actions_from_capabilities(capabilities_set)

          permissions << permission
        end

        permissions
      end

      def extract_principal_info_from_policy(path_parts)
        # path_parts structure: ["users", TYPE, IDENTIFIER]
        return [nil, nil] if path_parts.size < 3

        case path_parts[1]
        when 'direct'
          if path_parts[2].start_with?('user_')
            ['User', path_parts[2].sub('user_', '').to_i]
          elsif path_parts[2].start_with?('member_role_')
            ['MemberRole', path_parts[2].sub('member_role_', '').to_i]
          elsif path_parts[2].start_with?('group_')
            ['Group', path_parts[2].sub('group_', '').to_i]
          end
        when 'roles'
          role_id = path_parts[2]
          role_id ? ['Role', role_id] : [nil, nil]
        end
      end
    end
  end
end
