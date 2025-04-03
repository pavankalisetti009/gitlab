# frozen_string_literal: true

module EE
  module Projects
    module MarkForDeletionService
      extend ::Gitlab::Utils::Override
      include SecurityOrchestrationHelper

      override :execute
      def execute(*)
        return success if project.marked_for_deletion_at?

        if reject_security_policy_project_deletion?
          return error(
            s_('SecurityOrchestration|Project cannot be deleted because it is linked as a security policy project')
          )
        end

        result = super(licensed: License.feature_available?(:adjourned_deletion_for_projects_and_groups))

        send_project_deletion_notification if result[:status] == :success

        result
      end

      private

      def send_project_deletion_notification
        return unless ::Feature.enabled?(:project_deletion_notification_email, project) &&
          project.adjourned_deletion? &&
          project.marked_for_deletion?

        ::NotificationService.new.project_scheduled_for_deletion(project)
      end

      override :log_event
      def log_event
        log_audit_event

        super
      end

      def log_audit_event
        audit_context = {
          name: 'project_deletion_marked',
          author: current_user,
          scope: project,
          target: project,
          message: 'Project marked for deletion'
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      override :project_update_service_params
      def project_update_service_params
        hide_project? ? super.merge(hidden: true) : super
      end

      def reject_security_policy_project_deletion?
        security_configurations_preventing_project_deletion(project).exists?
      end

      # We hide unlicensed projects on a licensed instance, such as SaaS. This ensures that delayed deletion
      # is only exposed to premium users while still performing a delayed delete behind the scenes.
      def hide_project?
        return false if project.licensed_feature_available?(:adjourned_deletion_for_projects_and_groups)

        !feature_downtiered?
      end
    end
  end
end
