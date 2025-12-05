# frozen_string_literal: true

module SecretsManagement
  module SecretsPermissions
    module DeleteServiceHelpers
      extend ActiveSupport::Concern

      def execute(principal:)
        with_exclusive_lease_for(resource) do
          execute_delete_permission(principal: principal)
        end
      end

      private

      delegate :secrets_manager, to: :resource

      def execute_delete_permission(principal:)
        return secrets_manager_inactive_response unless secrets_manager&.active?
        return invalid_principal_response unless valid_principal?(principal)

        secrets_permission = secrets_manager.policy_name_for_principal(
          principal_type: principal[:type],
          principal_id: principal[:id])

        delete_permission(secrets_permission)
      end

      def delete_permission(secrets_permission)
        client.delete_policy(secrets_permission)
        ServiceResponse.success(payload: { secrets_permission: nil })
      end

      def valid_principal?(principal)
        return false if principal.blank? || principal[:type].blank? || principal[:id].blank?

        valid_type = SecretsManagement::BaseSecretsPermission::VALID_PRINCIPAL_TYPES.include?(principal[:type])
        valid_id = principal[:id].to_s.match?(/\A\d+\z/)
        valid_type && valid_id
      end

      def invalid_principal_response
        ServiceResponse.error(message: 'Invalid principal')
      end
    end
  end
end
