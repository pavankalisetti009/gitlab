# frozen_string_literal: true

module EE
  module Groups # rubocop:disable Gitlab/BoundedContexts -- existing top-level module
    module MarkForDeletionService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(*)
        super(licensed: License.feature_available?(:adjourned_deletion_for_projects_and_groups))
      end

      private

      override :send_group_deletion_notification
      def send_group_deletion_notification
        return unless ::Feature.enabled?(:group_deletion_notification_email, group) &&
          group.adjourned_deletion?

        ::NotificationService.new.group_scheduled_for_deletion(group)
      end

      override :log_event
      def log_event
        log_audit_event

        super
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
