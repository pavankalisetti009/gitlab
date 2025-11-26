# frozen_string_literal: true

module Vulnerabilities
  class TriggerResolutionWorkflowWorker
    include ApplicationWorker

    StartWorkflowServiceError = Class.new(StandardError)

    data_consistency :delayed
    feature_category :vulnerability_management
    urgency :throttled
    idempotent!
    concurrency_limit -> { 100 }

    CONFIDENCE_THRESHOLD = 0.6
    WORKFLOW_DEFINITION = ::Ai::DuoWorkflows::WorkflowDefinition['resolve_sast_vulnerability/v1']

    def perform(vulnerability_flag_id)
      vulnerability_flag = find_vulnerability_flag(vulnerability_flag_id)
      return unless vulnerability_flag
      return unless vulnerability_flag.confidence_score < CONFIDENCE_THRESHOLD

      finding = vulnerability_flag.finding
      return unless ::Feature.enabled?(:enable_vulnerability_resolution, finding.project.root_ancestor)

      result = trigger_workflow(finding)
      if result.success?
        create_triggered_workflow_record(finding, result)
      else
        handle_error(result, vulnerability_flag, finding)
      end
    rescue StandardError => error
      log_exception(error, vulnerability_flag_id)
    end

    private

    def find_vulnerability_flag(vulnerability_flag_id)
      ::Vulnerabilities::Flag.with_associations.find_by_id(vulnerability_flag_id)
    end

    def trigger_workflow(finding)
      vulnerability = finding.vulnerability

      ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
        container: finding.project,
        current_user: vulnerability.author,
        workflow_definition: WORKFLOW_DEFINITION,
        goal: vulnerability.id.to_s,
        source_branch: finding.project.default_branch
      ).execute
    end

    def create_triggered_workflow_record(finding, response)
      workflow_id = response.payload[:workflow_id]

      ::Vulnerabilities::TriggeredWorkflow.create!(
        vulnerability_occurrence_id: finding.id,
        workflow_id: workflow_id,
        workflow_name: :resolve_sast_vulnerability
      )
    rescue ActiveRecord::RecordInvalid => error
      Gitlab::ErrorTracking.track_exception(
        error,
        vulnerability_id: finding.vulnerability_id,
        workflow_id: workflow_id
      )
    end

    def handle_error(result, vulnerability_flag, finding)
      Gitlab::AppLogger.error(
        message: 'Failed to create and start workflow for vulnerability resolution',
        vulnerability_flag_id: vulnerability_flag.id,
        finding_id: finding.id,
        error: result.message,
        reason: result.reason
      )

      raise StartWorkflowServiceError, "Failed to start workflow for vulnerability resolution: #{result.message}"
    end

    def log_exception(error, vulnerability_flag_id)
      Gitlab::ErrorTracking.log_and_raise_exception(
        error,
        vulnerability_flag_id: vulnerability_flag_id
      )
    end
  end
end
