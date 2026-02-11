# frozen_string_literal: true

module Vulnerabilities
  class TriggerResolutionWorkflowWorker
    include ApplicationWorker
    include Gitlab::InternalEventsTracking

    StartWorkflowServiceError = Class.new(StandardError)

    data_consistency :delayed
    feature_category :vulnerability_management
    urgency :throttled
    idempotent!
    concurrency_limit -> { 100 }
    sidekiq_options retry: 10
    skip_composite_identity_passthrough!

    CONFIDENCE_THRESHOLD = 0.6
    WORKFLOW_DEFINITION = 'resolve_sast_vulnerability/v1'

    def perform(vulnerability_flag_id)
      vulnerability_flag = find_vulnerability_flag(vulnerability_flag_id)
      return unless vulnerability_flag
      return unless vulnerability_flag.confidence_score < CONFIDENCE_THRESHOLD

      finding = vulnerability_flag.finding
      return unless ::Feature.enabled?(:enable_vulnerability_resolution, finding.project.root_ancestor)
      return unless finding.project.duo_sast_vr_workflow_enabled

      result = trigger_workflow(finding)
      if result.success?
        track_event(finding) if create_triggered_workflow_record(finding, result)
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
      project = finding.project
      user = project.first_owner || vulnerability.author

      consumer = find_consumer(user, project)
      log_consumer_not_found(finding) unless consumer

      service_account = find_service_account(consumer)

      flow_params = {
        item_consumer: consumer,
        service_account: service_account,
        execute_workflow: true,
        event_type: 'sidekiq_worker',
        user_prompt: vulnerability.id.to_s
      }

      ::Ai::Catalog::Flows::ExecuteService.new(
        project: project,
        current_user: user,
        params: flow_params
      ).execute
    end

    def find_consumer(user, project)
      ::Ai::Catalog::ItemConsumersFinder.new(user, params: {
        project_id: project.id,
        item_type: Ai::Catalog::Item::FLOW_TYPE,
        foundational_flow_reference: WORKFLOW_DEFINITION
      }).execute.first
    end

    def find_service_account(consumer)
      return unless consumer

      if consumer.project.present?
        consumer.parent_item_consumer&.service_account
      else
        consumer.service_account
      end
    end

    def log_consumer_not_found(finding)
      Gitlab::AppLogger.error(
        message: 'No consumer configured for vulnerability resolution workflow',
        finding_id: finding.id,
        project_id: finding.project_id,
        workflow_definition: WORKFLOW_DEFINITION
      )
    end

    def create_triggered_workflow_record(finding, response)
      workflow = response.payload[:workflow]
      return unless workflow

      ::Vulnerabilities::TriggeredWorkflow.create!(
        vulnerability_occurrence_id: finding.id,
        workflow_id: workflow.id,
        workflow_name: :resolve_sast_vulnerability
      )
    rescue ActiveRecord::RecordInvalid => error
      Gitlab::ErrorTracking.track_exception(
        error,
        vulnerability_id: finding.vulnerability_id,
        workflow_id: workflow&.id
      )

      nil
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

    def track_event(finding)
      vulnerability = finding.vulnerability

      track_internal_event(
        'trigger_sast_vulnerability_resolution_workflow',
        project: finding.project,
        additional_properties: {
          label: 'automatic',
          value: vulnerability.id,
          property: vulnerability.severity
        }
      )
    end
  end
end
