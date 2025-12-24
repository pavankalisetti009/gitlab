# frozen_string_literal: true

module Vulnerabilities
  class TriggerFalsePositiveDetectionWorkflowWorker
    include ApplicationWorker
    include Gitlab::InternalEventsTracking

    StartWorkflowServiceError = Class.new(StandardError)
    WORKFLOW_DEFINITION = 'sast_fp_detection/v1'

    feature_category :static_application_security_testing
    data_consistency :delayed
    urgency :throttled
    idempotent!
    concurrency_limit -> { 100 }

    def perform(vulnerability_id)
      vulnerability = find_vulnerability(vulnerability_id)
      return unless vulnerability

      return unless ::Feature.enabled?(:enable_vulnerability_fp_detection, vulnerability.group)

      result = trigger_workflow(vulnerability)

      if result.success?
        track_event(vulnerability) if create_triggered_workflow_record(vulnerability, result)
      else
        handle_error(result, vulnerability)
      end
    rescue StandardError => error
      log_and_raise_exception(error, vulnerability_id)
    end

    private

    def find_vulnerability(vulnerability_id)
      ::Vulnerability.find_by_id(vulnerability_id)
    end

    def trigger_workflow(vulnerability)
      project = vulnerability.project

      ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
        container: project,
        current_user: project.first_owner || vulnerability.author,
        workflow_definition: ::Ai::DuoWorkflows::WorkflowDefinition[WORKFLOW_DEFINITION],
        goal: vulnerability.id.to_s,
        source_branch: project.default_branch
      ).execute
    end

    def handle_error(result, vulnerability)
      Gitlab::AppLogger.error(
        message: 'Failed to call SAST workflow service for vulnerability',
        vulnerability_id: vulnerability.id,
        project_id: vulnerability.project.id,
        error: result.message,
        reason: result.reason
      )

      raise StartWorkflowServiceError, "Failed to call SAST workflow service for vulnerability #{result.message}"
    end

    def log_and_raise_exception(error, vulnerability_id)
      Gitlab::ErrorTracking.log_and_raise_exception(
        error,
        vulnerability_id: vulnerability_id
      )
    end

    def create_triggered_workflow_record(vulnerability, response)
      ::Vulnerabilities::TriggeredWorkflow.create!(
        vulnerability_occurrence_id: vulnerability.finding.id,
        workflow_id: response.payload[:workflow_id],
        workflow_name: :sast_fp_detection
      )
    rescue ActiveRecord::RecordInvalid => error
      Gitlab::ErrorTracking.track_exception(
        error,
        vulnerability_id: vulnerability.id,
        workflow_id: response.payload[:workflow_id]
      )

      nil
    end

    def track_event(vulnerability)
      track_internal_event(
        'trigger_sast_vulnerability_fp_detection_workflow',
        project: vulnerability.project,
        additional_properties: {
          label: 'automatic',
          value: vulnerability.id,
          property: vulnerability.severity
        }
      )
    end
  end
end
