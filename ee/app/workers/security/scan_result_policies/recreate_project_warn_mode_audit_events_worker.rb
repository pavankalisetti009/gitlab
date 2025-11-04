# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class RecreateProjectWarnModeAuditEventsWorker
      include Gitlab::EventStore::Subscriber

      feature_category :security_policy_management
      data_consistency :sticky
      idempotent!

      def handle_event(event)
        project_id = event.data[:project_id]

        project = Project.find_by_id(project_id) || return

        return unless project.licensed_feature_available?(:security_orchestration_policies)
        return unless Feature.enabled?(:security_policy_approval_warn_mode, project)

        AuditEvent.transaction do
          project.approval_policies.select(&:warn_mode?).each do |policy|
            Security::ScanResultPolicies::CreateProjectWarnModeAuditEventService
              .new(project, policy)
              .execute
          end
        end
      end
    end
  end
end
