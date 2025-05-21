# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class RunScheduleWorker
      include ApplicationWorker

      idempotent!
      deduplicate :until_executing, including_scheduled: true,
        ttl: Security::PipelineExecutionProjectSchedule::MAX_TIME_WINDOW

      data_consistency :sticky
      feature_category :security_policy_management

      PIPELINE_SOURCE = :pipeline_execution_policy_schedule
      EVENT_KEY = 'scheduled_pipeline_execution_policy_failure'

      def perform(schedule_id)
        schedule = Security::PipelineExecutionProjectSchedule.find_by_id(schedule_id) || return

        return if Feature.disabled?(:scheduled_pipeline_execution_policies, schedule.project)

        return unless experiment_enabled?(schedule)

        if schedule.snoozed?
          ::Gitlab::InternalEvents.track_event('scheduled_pipeline_execution_policy_snoozed', project: schedule.project)

          return
        end

        result = execute(schedule)

        log_pipeline_creation_failure(result, schedule) if result.error?
      end

      private

      def execute(schedule)
        ci_content = schedule.ci_content.deep_stringify_keys.to_yaml

        result = Ci::CreatePipelineService.new(
          schedule.project,
          schedule.project.security_policy_bot,
          ref: schedule.project.default_branch_or_main
        ).execute(PIPELINE_SOURCE, content: ci_content, ignore_skip_ci: true)

        ::Gitlab::InternalEvents.track_event(
          'execute_job_scheduled_pipeline_execution_policy',
          project: schedule.project,
          additional_properties: {
            label: result.status.to_s
          }
        )

        result
      end

      def log_pipeline_creation_failure(result, schedule)
        Gitlab::AppJsonLogger.error(
          build_structured_payload(
            event: EVENT_KEY,
            message: result.message,
            reason: result.reason,
            project_id: schedule.project_id,
            schedule_id: schedule.id,
            policy_id: schedule.security_policy.id))
      end

      def experiment_enabled?(schedule)
        schedule
          .security_policy
          .security_orchestration_policy_configuration
          .experiment_enabled?(:pipeline_execution_schedule_policy)
      end
    end
  end
end
