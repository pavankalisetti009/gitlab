# frozen_string_literal: true

module Projects
  class MarkForDeletionService < BaseService
    LEGACY_DELETION_SCHEDULED_PATH_IDENTIFIER = 'deleted'
    DELETION_SCHEDULED_PATH_IDENTIFIER = 'deletion_scheduled'

    UnauthorizedError = ServiceResponse.error(message: 'You are not authorized to perform this action')
    AlreadyMarkedForDeletionError = ServiceResponse.error(message: 'Project has been already marked for deletion')

    def execute
      result = preconditions_checks
      return result if result.error?

      result = ServiceResponse.from_legacy_hash(
        ::Projects::UpdateService.new(
          project,
          current_user,
          project_update_service_params
        ).execute
      )

      if result.success?
        log_event
        send_project_deletion_notification

        ## Trigger root statistics refresh, to skip project_statistics of
        ## projects marked for deletion
        ::Namespaces::ScheduleAggregationWorker.perform_async(project.namespace_id)
      else
        log_error(result.message)
      end

      result
    end

    private

    def preconditions_checks
      return UnauthorizedError unless can?(current_user, :remove_project, project)
      return AlreadyMarkedForDeletionError if project.self_deletion_scheduled?

      ServiceResponse.success
    end

    def send_project_deletion_notification
      notification_service.project_scheduled_for_deletion(project)
    end

    def log_event
      log_info("User #{current_user.id} marked project #{project.full_path} for deletion")
    end

    def project_update_service_params
      {
        archived: true,
        name: suffixed_identifier(project.name),
        path: suffixed_identifier(project.path),
        marked_for_deletion_at: Time.current.utc,
        deleting_user: current_user
      }
    end

    def suffixed_identifier(original_identifier)
      if Feature.enabled?(:rename_group_path_upon_deletion_scheduling, project.root_ancestor)
        "#{original_identifier}-#{DELETION_SCHEDULED_PATH_IDENTIFIER}-#{project.id}"
      else
        "#{original_identifier}-#{LEGACY_DELETION_SCHEDULED_PATH_IDENTIFIER}-#{project.id}"
      end
    end
  end
end

Projects::MarkForDeletionService.prepend_mod
