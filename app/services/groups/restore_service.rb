# frozen_string_literal: true

module Groups
  class RestoreService < Groups::BaseService
    include Gitlab::Utils::StrongMemoize

    DELETED_SUFFIX_REGEX = /-#{Groups::MarkForDeletionService::DELETION_SCHEDULED_PATH_IDENTIFIER}-\d+\z/

    UnauthorizedError = ServiceResponse.error(message: 'You are not authorized to perform this action')
    NotMarkedForDeletionError = ServiceResponse.error(message: 'Group has not been marked for deletion')
    DeletionInProgressError = ServiceResponse.error(message: 'Group deletion is in progress')

    RenamingFailedError = Class.new(StandardError)
    DeletionScheduleDestroyingFailedError = Class.new(StandardError)

    def execute
      result = preconditions_checks
      return result if result.error?

      result = ServiceResponse.success

      group.transaction do
        rename_resource!
        destroy_deletion_schedule!
      rescue RenamingFailedError
        result = ServiceResponse.error(message: group.errors.full_messages.to_sentence)
        raise ActiveRecord::Rollback
      rescue DeletionScheduleDestroyingFailedError
        result = ServiceResponse.error(message: _('Could not restore the group'))
        raise ActiveRecord::Rollback
      end

      if result.success?
        log_event
        group.reset
      end

      result
    end

    private

    def preconditions_checks
      return UnauthorizedError unless can?(current_user, :remove_group, group)
      return NotMarkedForDeletionError unless group.self_deletion_scheduled?
      return DeletionInProgressError if group.self_deletion_in_progress?

      ServiceResponse.success
    end

    def rename_resource!
      successful = ::Groups::UpdateService.new(
        group,
        current_user,
        { name: updated_value(group.name), path: updated_value(group.path) }
      ).execute
      return if successful

      raise RenamingFailedError
    end

    def updated_value(value)
      "#{original_value(value)}#{suffix}"
    end

    def original_value(value)
      value.sub(DELETED_SUFFIX_REGEX, '')
    end

    def suffix
      original_path_taken?(group) ? "-#{SecureRandom.alphanumeric(5)}" : ""
    end
    strong_memoize_attr :suffix

    def original_path_taken?(group)
      existing_group = ::Group.find_by_full_path(original_value(group.full_path))

      existing_group.present? && existing_group.id != group.id
    end

    def destroy_deletion_schedule!
      return if group.deletion_schedule.destroy

      raise DeletionScheduleDestroyingFailedError
    end

    def log_event
      log_info("User #{current_user.id} restored group #{group.full_path}")
    end
  end
end

Groups::RestoreService.prepend_mod
