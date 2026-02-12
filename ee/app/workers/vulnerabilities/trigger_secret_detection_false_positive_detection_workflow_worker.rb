# frozen_string_literal: true

module Vulnerabilities
  class TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker
    include ApplicationWorker
    include Gitlab::InternalEventsTracking

    StartWorkflowServiceError = Class.new(StandardError)
    WORKFLOW_DEFINITION = 'secrets_fp_detection/v1'

    feature_category :vulnerability_management
    data_consistency :delayed
    defer_on_database_health_signal :gitlab_sec, [:vulnerabilities], 5.minutes
    urgency :throttled
    idempotent!
    concurrency_limit -> { 100 }
    sidekiq_options retry: 10

    def perform(vulnerability_id)
      vulnerability = find_vulnerability(vulnerability_id)
      return unless vulnerability

      return unless ::Feature.enabled?(:duo_secret_detection_false_positive, vulnerability.group)

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
      user = project.first_owner || vulnerability.author

      consumer = find_consumer(user, project)
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
      consumer&.parent_item_consumer&.service_account
    end

    def handle_error(result, vulnerability)
      Gitlab::AppLogger.error(
        message: 'Failed to call Secret Detection workflow service for vulnerability',
        vulnerability_id: vulnerability.id,
        project_id: vulnerability.project.id,
        error: result.message,
        reason: result.reason
      )

      raise StartWorkflowServiceError,
        "Failed to call Secret Detection workflow service for vulnerability #{result.message}"
    end

    def log_and_raise_exception(error, vulnerability_id)
      Gitlab::ErrorTracking.log_and_raise_exception(
        error,
        vulnerability_id: vulnerability_id
      )
    end

    def create_triggered_workflow_record(vulnerability, response)
      ::Vulnerabilities::TriggeredWorkflow.create!(
        vulnerability_occurrence_id: vulnerability.finding&.id,
        workflow_id: response.payload[:workflow_id],
        workflow_name: :secrets_fp_detection
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
        'trigger_secret_detection_vulnerability_fp_detection_workflow',
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
