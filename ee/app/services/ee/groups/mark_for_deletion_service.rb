# frozen_string_literal: true

module EE
  module Groups # rubocop:disable Gitlab/BoundedContexts -- existing top-level module
    module MarkForDeletionService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(*)
        return error(_('You are not authorized to perform this action')) unless can?(current_user, :remove_group, group)
        return error(_('Group has been already marked for deletion')) if group.marked_for_deletion?

        result = create_deletion_schedule
        log_audit_event if result[:status] == :success

        send_group_deletion_notification

        result
      end

      private

      def send_group_deletion_notification
        return unless ::Feature.enabled?(:group_deletion_notification_email, group) &&
          group.adjourned_deletion?

        ::NotificationService.new.group_scheduled_for_deletion(group)
      end

      def create_deletion_schedule
        deletion_schedule = group.build_deletion_schedule(deletion_schedule_params)

        if deletion_schedule.save
          success
        else
          errors = deletion_schedule.errors.full_messages.to_sentence

          error(errors)
        end
      end

      def deletion_schedule_params
        { marked_for_deletion_on: Time.current.utc, deleting_user: current_user }
      end

      def log_audit_event
        audit_context = {
          name: 'group_deletion_marked',
          author: current_user,
          scope: group,
          target: group,
          message: 'Group marked for deletion'
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
