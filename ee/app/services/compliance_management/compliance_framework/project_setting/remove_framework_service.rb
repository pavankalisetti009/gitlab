# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ProjectSetting
      class RemoveFrameworkService < BaseService
        def initialize(project_id:, current_user:, framework:)
          @project_id = project_id
          @current_user = current_user
          @framework = framework
        end

        def execute
          return error unless framework.projects.destroy(project_id)

          enqueue_project_compliance_status_removal
          publish_event
          audit_event

          success
        rescue ActiveRecord::RecordNotFound
          success
        end

        private

        def project
          @project ||= Project.find(project_id)
        end

        attr_reader :project_id, :current_user, :framework

        def publish_event
          event = ::Projects::ComplianceFrameworkChangedEvent.new(data: {
            project_id: project_id,
            compliance_framework_id: framework.id,
            event_type: ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed]
          })

          ::Gitlab::EventStore.publish(event)
        end

        def audit_event
          event_type = ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed]

          audit_context = {
            name: "compliance_framework_#{event_type}",
            author: current_user,
            scope: project,
            target: framework,
            message: %(#{event_type.capitalize} 'framework label': "#{framework.name}"),
            additional_details: {
              framework: {
                id: framework.id,
                name: framework.name
              }
            }
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def success
          ServiceResponse.success
        end

        def error
          ServiceResponse.error(message: format(_("Failed to remove the framework from project %{project_name}"),
            project_name: project.name))
        end

        def enqueue_project_compliance_status_removal
          ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker.perform_in(
            ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
            project_id, framework.id
          )
        end
      end
    end
  end
end
