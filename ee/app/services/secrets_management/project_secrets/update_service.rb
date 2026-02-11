# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class UpdateService < ProjectBaseService
      include Secrets::UpdateServiceHelpers
      include ProjectSecrets::SecretRefresherHelper

      def execute(
        name:,
        metadata_cas: nil,
        value: nil,
        description: nil,
        environment: nil,
        branch: nil,
        rotation_interval_days: nil
      )
        with_exclusive_lease_for(project) do
          read_result = read_secret(name)
          break read_result unless read_result.success?

          project_secret = read_result.payload[:secret]
          project_secret.description = description unless description.nil?
          project_secret.environment = environment unless environment.nil?
          project_secret.branch = branch unless branch.nil?

          break error_response(project_secret) unless project_secret.valid_for_update?

          secret_rotation_info = build_secret_rotation_info(project_secret, metadata_cas, rotation_interval_days)

          # Based on https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/secret_manager/decisions/010_secret_rotation_metadata_storage/
          # we want to create/update the secret rotation info record first.
          if !secret_rotation_info&.upsert && secret_rotation_info&.invalid?
            break secret_rotation_info_invalid_error(project_secret, secret_rotation_info)
          end

          project_secret.rotation_info = secret_rotation_info

          execute_secret_update(
            secret: project_secret,
            custom_metadata: {
              environment: project_secret.environment,
              branch: project_secret.branch,
              secret_rotation_info_id: secret_rotation_info&.id
            },
            value: value,
            metadata_cas: metadata_cas
          )
        end
      end

      private

      delegate :secrets_manager, to: :project

      def read_secret(name)
        # No need to include rotation info in this case because we just want to upsert if ever
        ProjectSecrets::ReadMetadataService.new(project, current_user)
          .execute(name, include_rotation_info: false)
      end

      def build_secret_rotation_info(project_secret, metadata_cas, rotation_interval_days)
        return unless rotation_interval_days

        SecretRotationInfo.new(
          project: project,
          secret_name: project_secret.name,
          rotation_interval_days: rotation_interval_days,
          secret_metadata_version: (metadata_cas || project_secret.metadata_version) + 1
        )
      end

      def refresh_policies_after_update(project_secret)
        refresh_secret_ci_policies(project_secret)
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
