# frozen_string_literal: true

module EE
  module Groups
    module MarkForDeletionService
      extend ::Gitlab::Utils::Override

      private

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
