# frozen_string_literal: true

module Groups
  class MarkForDeletionService < BaseService
    DELETION_SCHEDULED_PATH_IDENTIFIER = 'deletion_scheduled'

    UnauthorizedError = ServiceResponse.error(message: 'You are not authorized to perform this action')
    AlreadyMarkedForDeletionError = ServiceResponse.error(message: 'Group has been already marked for deletion')

    RenamingFailedError = Class.new(StandardError)
    DeletionScheduleSavingFailedError = Class.new(StandardError)

    def execute
      result = preconditions_checks
      return result if result.error?

      deletion_schedule = group.build_deletion_schedule(
        marked_for_deletion_on: Time.current.utc,
        deleting_user: current_user
      )

      error = nil

      group.transaction do
        rename_group_for_deletion! if rename_group_for_deletion?
        save_deletion_schedule!(deletion_schedule)
      rescue RenamingFailedError
        error = group.errors.full_messages.to_sentence
        raise ActiveRecord::Rollback
      rescue DeletionScheduleSavingFailedError
        error = deletion_schedule.errors.full_messages.to_sentence
        raise ActiveRecord::Rollback
      end

      if error
        ServiceResponse.error(message: error)
      else
        log_event
        send_group_deletion_notification
        ServiceResponse.success
      end
    end

    private

    def preconditions_checks
      return UnauthorizedError unless can?(current_user, :remove_group, group)
      return AlreadyMarkedForDeletionError if group.self_deletion_scheduled?

      ServiceResponse.success
    end

    def rename_group_for_deletion?
      Feature.enabled?(:rename_group_path_upon_deletion_scheduling, group.root_ancestor) &&
        !group.has_container_repository_including_subgroups?
    end

    def rename_group_for_deletion!
      successful = ::Groups::UpdateService.new(
        group,
        current_user,
        { name: suffixed_identifier(group.name), path: suffixed_identifier(group.path) }
      ).execute
      return if successful

      raise RenamingFailedError
    end

    def suffixed_identifier(original_identifier)
      "#{original_identifier}-#{DELETION_SCHEDULED_PATH_IDENTIFIER}-#{group.id}"
    end

    def save_deletion_schedule!(deletion_schedule)
      return if deletion_schedule.save

      raise DeletionScheduleSavingFailedError
    end

    def log_event
      log_info("User #{current_user.id} marked group #{group.full_path} for deletion")
    end

    def send_group_deletion_notification
      notification_service.group_scheduled_for_deletion(group)
    end
  end
end

Groups::MarkForDeletionService.prepend_mod
