# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class ScheduleWorker
      include ApplicationWorker
      include CronjobQueue
      include Security::SecurityOrchestrationPolicies::CadenceChecker
      include ExclusiveLeaseGuard

      LEASE_KEY = 'security_pipeline_execution_policies_schedule'
      LEASE_TIMEOUT = 5.minutes

      idempotent!

      data_consistency :sticky
      feature_category :security_policy_management

      def perform
        try_obtain_lease do
          scope = Security::PipelineExecutionProjectSchedule
            .runnable_schedules
            .including_security_policy_and_project
            .ordered_by_next_run_at

          iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

          iterator.each_batch(of: 1000) do |schedules|
            schedules.each do |schedule|
              next unless Feature.enabled?(:scheduled_pipeline_execution_policies, schedule.project)

              unless valid_cadence?(schedule.cron)
                log_invalid_cadence_error(schedule.project_id, schedule.cron)

                next
              end

              enqueue_within_time_window(schedule)

              schedule.schedule_next_run!
            end
          end
        end
      end

      private

      def enqueue_within_time_window(schedule)
        time_window = [schedule.time_window_seconds, schedule.next_run_in].min

        delay = Random.rand(time_window)

        with_context(project: schedule.project_id) do
          Security::PipelineExecutionPolicies::RunScheduleWorker.perform_in(delay, schedule.id)
        end
      end

      def lease_key
        LEASE_KEY
      end

      def lease_timeout
        LEASE_TIMEOUT
      end
    end
  end
end
