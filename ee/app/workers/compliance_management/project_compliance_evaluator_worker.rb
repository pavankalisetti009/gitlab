# frozen_string_literal: true

module ComplianceManagement
  class ProjectComplianceEvaluatorWorker
    include ApplicationWorker

    version 1
    data_consistency :sticky
    feature_category :compliance_management
    deduplicate :until_executed, including_scheduled: true
    idempotent!
    urgency :low

    def self.schedule_compliance_evaluation(framework_id, project_ids)
      perform_in(
        ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
        framework_id, project_ids
      )
    end

    def perform(framework_id, project_ids)
      return unless Feature.enabled?(:evaluate_compliance_controls, :instance)

      framework = ::ComplianceManagement::Framework.find_by_id(framework_id)
      return unless framework

      internal_controls = internal_controls_for(framework)
      projects = ::Project.id_in(project_ids & framework.project_ids)
      evaluation_results = []

      projects.each do |project|
        approval_settings = framework.approval_settings_from_security_policies(project)

        internal_controls.each do |control|
          status = ::ComplianceManagement::ComplianceRequirements::ExpressionEvaluator.new(control,
            project, approval_settings).evaluate
          evaluation_results << {
            project: project,
            control: control,
            status_value: status ? 'pass' : 'fail'
          }
        rescue StandardError => e
          Gitlab::ErrorTracking.log_exception(
            e,
            framework_id: control.compliance_requirement.framework_id,
            control_id: control.id,
            project_id: project.id
          )
        end
      end

      update_all_control_statuses(evaluation_results)
    end

    private

    def internal_controls_for(framework)
      ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl.internal_for_framework(framework.id)
    end

    def update_all_control_statuses(evaluation_results)
      evaluation_results.each do |result|
        ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService.new(
          current_user: ::Gitlab::Audit::UnauthenticatedAuthor.new,
          control: result[:control],
          project: result[:project],
          status_value: result[:status_value]
        ).execute
      rescue StandardError => e
        Gitlab::ErrorTracking.log_exception(
          e,
          framework_id: result[:control].compliance_requirement.framework_id,
          control_id: result[:control].id,
          project_id: result[:project].id,
          status_value: result[:status_value]
        )
      end
    end
  end
end
