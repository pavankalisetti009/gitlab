# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class UpdateService < BaseService
      include Gitlab::Utils::StrongMemoize
      include SecretsManagerClientHelpers
      include CiPolicies::SecretRefresherHelper
      include Helpers::UserClientHelper

      def execute(
        name:,
        metadata_cas: nil,
        value: nil,
        description: nil,
        environment: nil,
        branch: nil,
        rotation_interval_days: nil
      )
        return inactive_response unless project.secrets_manager&.active?

        read_result = read_project_secret(name)
        return read_result unless read_result.success?

        project_secret = read_result.payload[:project_secret]

        project_secret.description = description unless description.nil?
        project_secret.environment = environment unless environment.nil?
        project_secret.branch = branch unless branch.nil?

        update_secret(
          project_secret,
          value,
          metadata_cas,
          build_secret_rotation_info(project_secret, metadata_cas, rotation_interval_days)
        )
      end

      private

      delegate :secrets_manager, to: :project

      def build_secret_rotation_info(project_secret, metadata_cas, rotation_interval_days)
        return unless rotation_interval_days

        SecretRotationInfo.new(
          project: project,
          secret_name: project_secret.name,
          rotation_interval_days: rotation_interval_days,
          secret_metadata_version: (metadata_cas || project_secret.metadata_version) + 1
        )
      end

      def update_secret(project_secret, value, metadata_cas, secret_rotation_info)
        return error_response(project_secret) unless project_secret.valid?

        if secret_rotation_info&.invalid?
          return secret_rotation_info_invalid_error(project_secret, secret_rotation_info)
        end

        # Based on https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/secret_manager/decisions/010_secret_rotation_metadata_storage/
        # we want to create/update the secret rotation info record first.
        secret_rotation_info&.upsert

        custom_metadata = {
          environment: project_secret.environment,
          branch: project_secret.branch,
          description: project_secret.description,
          secret_rotation_info_id: secret_rotation_info&.id
        }.compact

        # NOTE: The current implementation makes two separate API calls (one for the value, one for metadata).
        # In the future, the secret value update will be handled directly in the frontend for better security,
        # before calling this service. However, the metadata update and policy management will still be handled
        # in this Rails backend service, as they contain essential information for access control.

        # We need to do the metadata update first just in case the metadata_cas does not match
        user_client.update_kv_secret_metadata(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          custom_metadata,
          metadata_cas: metadata_cas
        )

        if value
          user_client.update_kv_secret(
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(project_secret.name),
            value
          )
        end

        refresh_secret_ci_policies(project_secret)

        project_secret.metadata_version = metadata_cas ? metadata_cas + 1 : nil
        project_secret.rotation_info = secret_rotation_info

        ServiceResponse.success(payload: { project_secret: project_secret })
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('metadata check-and-set parameter does not match the current version')

        project_secret.errors.add(
          :base,
          "This secret has been modified recently. Please refresh the page and try again."
        )
        error_response(project_secret)
      end

      def read_project_secret(name)
        # No need to include rotation info in this case because we just want to upsert if ever
        ProjectSecrets::ReadService.new(project, current_user)
          .execute(name, include_rotation_info: false)
      end

      def error_response(project_secret)
        ServiceResponse.error(
          message: project_secret.errors.full_messages.to_sentence,
          payload: { project_secret: project_secret }
        )
      end

      def secret_rotation_info_invalid_error(project_secret, secret_rotation_info)
        secret_rotation_info.errors.full_messages.each do |message|
          project_secret.errors.add(:base, "Rotation configuration error: #{message}")
        end

        error_response(project_secret)
      end

      def inactive_response
        ServiceResponse.error(message: 'Project secrets manager is not active')
      end
    end
  end
end
