# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    module ProjectSetting
      class AddFrameworkService < BaseService
        def initialize(project_id:, current_user:, framework:)
          @project_id = project_id
          @current_user = current_user
          @framework = framework
        end

        def execute
          @project = Project.find(@project_id)

          return error unless framework.projects.push project

          enqueue_project_framework_evaluation
          publish_event
          audit_event

          success
        rescue ActiveRecord::RecordNotFound
          error
        rescue ActiveRecord::RecordNotUnique
          success
        end

        private

        attr_reader :project, :current_user, :framework

        def publish_event
          event = ::Projects::ComplianceFrameworkChangedEvent.new(data: {
            project_id: project.id,
            compliance_framework_id: framework.id,
            event_type: ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]
          })

          ::Gitlab::EventStore.publish(event)
        end

        def audit_event
          event_type = ::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added]

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
          message = _("Project not found") unless project

          message ||= format(_("Failed to assign the framework to project %{project_name}"),
            project_name: project.name)

          ServiceResponse.error(message:)
        end

        def enqueue_project_framework_evaluation
          ComplianceManagement::ProjectComplianceEvaluatorWorker.schedule_compliance_evaluation(
            framework.id, [project.id]
          )
        end
      end
    end
  end
end
