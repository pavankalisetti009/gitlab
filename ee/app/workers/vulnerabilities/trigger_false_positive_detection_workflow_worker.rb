# frozen_string_literal: true

module Vulnerabilities
  class TriggerFalsePositiveDetectionWorkflowWorker
    include ApplicationWorker

    feature_category :vulnerability_management
    data_consistency :delayed
    urgency :throttled
    idempotent!
    concurrency_limit -> { 100 }

    AGENT_PRIVILEGES = [
      ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
      ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
      ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
      ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
      ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
    ].freeze

    def perform(vulnerability_id)
      vulnerability = find_vulnerability(vulnerability_id)
      return unless vulnerability

      return unless ::Feature.enabled?(:enable_vulnerability_fp_detection, vulnerability.group)

      result = trigger_workflow(vulnerability)
      handle_error(result, vulnerability) if result.error?
    rescue StandardError => error
      log_exception(error, vulnerability_id)
    end

    private

    def find_vulnerability(vulnerability_id)
      ::Vulnerability.find_by_id(vulnerability_id)
    end

    def trigger_workflow(vulnerability)
      ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
        container: vulnerability.project,
        current_user: vulnerability.author,
        workflow_definition: 'sast_fp_detection/v1',
        goal: vulnerability.id.to_s,
        source_branch: vulnerability.project.default_branch,
        workflow_params: build_workflow_params
      ).execute
    end

    def build_workflow_params
      {
        agent_privileges: AGENT_PRIVILEGES,
        pre_approved_agent_privileges: AGENT_PRIVILEGES,
        allow_agent_to_request_user: false,
        environment: 'web'
      }
    end

    def handle_error(result, vulnerability)
      Gitlab::AppLogger.error(
        message: 'Failed to call SAST workflow service for vulnerability',
        vulnerability_id: vulnerability.id,
        project_id: vulnerability.project.id,
        error: result.message,
        reason: result.reason
      )
    end

    def log_exception(error, vulnerability_id)
      Gitlab::ErrorTracking.log_exception(
        error,
        vulnerability_id: vulnerability_id
      )
    end
  end
end
