# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class CreateService < BaseService
      include Gitlab::Utils::StrongMemoize
      include SecretsManagerClientHelpers
      include CiPolicies::SecretRefresherHelper
      include Helpers::UserClientHelper

      # MAX_SECRET_SIZE sets the maximum size of a secret value; see note
      # below before removing.
      MAX_SECRET_SIZE = 10000

      def execute(name:, value:, environment:, branch:, description: nil, rotation_interval_days: nil)
        secret_rotation_info = build_secret_rotation_info(name, rotation_interval_days) if rotation_interval_days

        project_secret = ProjectSecret.new(
          name: name,
          description: description,
          project: project,
          branch: branch,
          environment: environment
        )

        store_secret(project_secret, value, secret_rotation_info)
      end

      private

      delegate :secrets_manager, to: :project

      def build_secret_rotation_info(name, rotation_interval_days)
        SecretRotationInfo.new(
          project: project,
          secret_name: name,
          rotation_interval_days: rotation_interval_days,
          secret_metadata_version: 1
        )
      end

      def store_secret(project_secret, value, secret_rotation_info)
        return error_response(project_secret) unless project_secret.valid?

        if secret_rotation_info&.invalid?
          return secret_rotation_info_invalid_error(project_secret, secret_rotation_info)
        end

        return secret_exists_error(project_secret) if secret_exists?(project_secret)

        # Before removing value from the above and sending value directly
        # to OpenBao, ensure it has been updated with request parameter
        # size limiting quotas.
        if value.bytesize > MAX_SECRET_SIZE
          project_secret.errors.add(:base, "Length of project secret value exceeds allowed limits (10k bytes).")
          return error_response(project_secret)
        end

        # Based on https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/secret_manager/decisions/010_secret_rotation_metadata_storage/
        # we want to create the secret rotation info record first.
        secret_rotation_info&.upsert

        # The follow API calls are ordered such that they fail closed: first we
        # create the secret and its metadata and then attach policy to it. If we
        # fail to attach policy, no pipelines can access it and only project-level
        # users can modify it in the future. Updating a secret to set missing
        # branch and environments will then allow pipelines to access the secret.

        create_secret(project_secret, value, secret_rotation_info)

        refresh_secret_ci_policies(project_secret)

        project_secret.metadata_version = 1
        project_secret.rotation_info = secret_rotation_info

        ServiceResponse.success(payload: { project_secret: project_secret })
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('check-and-set parameter did not match the current version')

        secret_exists_error(project_secret)
      end

      def secret_exists?(project_secret)
        # No need to include rotation info in this case because we just want to upsert if ever
        result = ProjectSecrets::ReadService.new(project, current_user)
          .execute(project_secret.name, include_rotation_info: false)

        result.success?
      end

      def secret_exists_error(project_secret)
        project_secret.errors.add(:base, 'Project secret already exists.')
        error_response(project_secret)
      end

      # NOTE: The current implementation makes two separate API calls (one for the value, one for metadata).
      # In the future, the secret value creation will be handled directly in the frontend for better security,
      # before calling this service. However, the metadata update and policy management will still be handled
      # in this Rails backend service, as they contain essential information for access control.
      def create_secret(project_secret, value, secret_rotation_info)
        user_client.update_kv_secret(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          value,
          cas: 0
        )

        custom_metadata = {
          environment: project_secret.environment,
          branch: project_secret.branch,
          description: project_secret.description,
          secret_rotation_info_id: secret_rotation_info&.id
        }.compact

        user_client.update_kv_secret_metadata(
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(project_secret.name),
          custom_metadata,
          metadata_cas: 0
        )
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
    end
  end
end
