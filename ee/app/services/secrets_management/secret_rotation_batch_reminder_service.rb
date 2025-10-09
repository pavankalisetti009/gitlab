# frozen_string_literal: true

module SecretsManagement
  class SecretRotationBatchReminderService
    include Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 100

    def initialize
      @processed_count = 0
      @skipped_count = 0
      @notification_service = NotificationService.new
    end

    def execute
      @processed_count = 0
      @skipped_count = 0

      SecretRotationInfo.pending_reminders
        .limit(BATCH_SIZE)
        .each do |rotation_info|
        if orphaned_rotation_record?(rotation_info)
          cleanup_orphaned_record(rotation_info)
          @skipped_count += 1
        else
          process_rotation_reminder(rotation_info)
        end
      end

      log_completion_stats

      {
        processed_count: processed_count,
        skipped_count: skipped_count
      }
    end

    private

    attr_reader :notification_service, :processed_count, :skipped_count

    def orphaned_rotation_record?(rotation_info)
      # If the secrets manager is inactive, all rotation records are orphaned
      return true unless rotation_info.project.secrets_manager&.active?

      # If secrets manager is active, check if the secret still exists in OpenBao
      # and if its metadata still references this rotation info record
      secret_metadata = secrets_manager_client_for_project(rotation_info.project)
        .read_secret_metadata(
          rotation_info.project.secrets_manager.ci_secrets_mount_path,
          rotation_info.project.secrets_manager.ci_data_path(rotation_info.secret_name)
        )

      return true if secret_metadata.nil? # Secret doesn't exist

      # Check if the secret's metadata still references this rotation info
      stored_rotation_info_id = secret_metadata.dig("custom_metadata", "secret_rotation_info_id")
      stored_rotation_info_id != rotation_info.id.to_s
    end

    def secrets_manager_client_for_project(project)
      # Create a system-level client without user context for validation purposes
      jwt = SecretsManagerJwt.new(
        current_user: project.first_owner, # No user context needed for system validation
        project: project
      ).encoded

      client = SecretsManagerClient.new(jwt: jwt)
      client.with_namespace(project.secrets_manager.full_project_namespace_path)
    end

    def cleanup_orphaned_record(rotation_info)
      rotation_info.destroy!

      log_orphaned_cleanup(rotation_info)
    end

    def process_rotation_reminder(rotation_info)
      notification_service.secret_rotation_reminder(rotation_info)

      rotation_info.notification_sent!

      @processed_count += 1

      log_processed_secret(rotation_info)
    end

    def log_processed_secret(rotation_info)
      Gitlab::AppLogger.info(
        message: 'Secret rotation reminder processed successfully',
        secret_name: rotation_info.secret_name,
        project_id: rotation_info.project_id,
        last_reminder_at: rotation_info.last_reminder_at,
        next_reminder_at: rotation_info.next_reminder_at
      )
    end

    def log_orphaned_cleanup(rotation_info)
      Gitlab::AppLogger.info(
        message: 'Cleaned up orphaned secret rotation record',
        secret_name: rotation_info.secret_name,
        project_id: rotation_info.project_id
      )
    end

    def log_completion_stats
      Gitlab::AppLogger.info(
        message: 'Secret rotation batch reminder service completed',
        processed_count: processed_count,
        skipped_count: skipped_count
      )
    end
  end
end
