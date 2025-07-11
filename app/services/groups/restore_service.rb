# frozen_string_literal: true

module Groups # rubocop:disable Gitlab/BoundedContexts -- existing top-level module
  class RestoreService < Groups::BaseService
    include Gitlab::Utils::StrongMemoize

    DELETED_SUFFIX_REGEX = /-deletion_scheduled-[a-zA-Z0-9]+\z/
    RenamingFailedError = Class.new(StandardError)
    DeletionScheduleDestroyingFailedError = Class.new(StandardError)

    def execute
      result = preconditions_checks
      return result if result.error?

      error = nil

      group.transaction do
        rename_group_for_restore!
        destroy_deletion_schedule!
      rescue RenamingFailedError
        error = group.errors.full_messages.to_sentence
        raise ActiveRecord::Rollback
      rescue DeletionScheduleDestroyingFailedError
        error = _('Could not restore the group')
        raise ActiveRecord::Rollback
      end

      if error
        ServiceResponse.error(message: error)
      else
        log_event
        group.reset
        ServiceResponse.success
      end
    end

    private

    def preconditions_checks
      unless can?(current_user, :remove_group, group)
        return ServiceResponse.error(message: _('You are not authorized to perform this action'))
      end

      unless group.self_deletion_scheduled?
        return ServiceResponse.error(message: _('Group has not been marked for deletion'))
      end

      return ServiceResponse.error(message: _('Group deletion is in progress')) if group.self_deletion_in_progress?

      ServiceResponse.success
    end

    def rename_group_for_restore!
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
