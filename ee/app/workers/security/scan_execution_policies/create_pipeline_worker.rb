# frozen_string_literal: true

module Security
  module ScanExecutionPolicies
    class CreatePipelineWorker # rubocop:disable Scalability/IdempotentWorker -- The worker should not run multiple times to avoid creating multiple pipelines
      include ApplicationWorker
      prepend Gitlab::ConditionalConcurrencyLimitControl

      CACHE_EXPIRES_IN = 1.second

      feature_category :security_policy_management
      deduplicate :until_executing
      urgency :throttled
      data_consistency :delayed

      concurrency_limit -> { Gitlab::CurrentSettings.security_policy_scheduled_scans_max_concurrency * 10 }

      def perform(project_id, current_user_id, schedule_id, branch)
        project = Project.find_by_id(project_id)
        return unless project

        current_user = User.find_by_id(current_user_id)
        return unless current_user

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(schedule_id)
        return unless schedule

        actions = actions_for(schedule)

        service_result = ::Security::SecurityOrchestrationPolicies::CreatePipelineService
          .new(project: project, current_user: current_user, params: { actions: actions, branch: branch })
          .execute

        return unless service_result[:status] == :error

        log_error(current_user, schedule, service_result[:message])
      end

      private

      def defer_job?(_, _, schedule_id, _)
        return false unless Feature.enabled?(:scan_execution_pipeline_concurrency_control)

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(schedule_id)
        return false unless schedule

        schedule_builds_count = actions_for(schedule).count
        project_ids = project_ids(schedule)

        max_scheduled_scans_concurrency > 0 && reached_limit?(limit: max_scheduled_scans_concurrency,
          schedule_builds_count: schedule_builds_count, project_ids: project_ids, schedule_id: schedule_id)
      end

      def project_ids(schedule)
        policy_configuration = schedule.security_orchestration_policy_configuration

        project = policy_configuration.project
        if project.present?
          project_ids = [project.id]
        else
          namespace = policy_configuration.namespace
          project_ids = namespace.all_projects.pluck(:id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- avoids cross-schema error
        end

        project_ids
      end

      def max_scheduled_scans_concurrency
        Gitlab::CurrentSettings.security_policy_scheduled_scans_max_concurrency
      end

      def cache_key(schedule_id)
        "security_policy_concurrency_control:#{schedule_id}"
      end

      def reached_limit?(limit:, schedule_builds_count:, project_ids:, schedule_id:)
        active_builds = Rails.cache.fetch(cache_key(schedule_id), expires_in: CACHE_EXPIRES_IN) do
          ::Ci::Build.with_pipeline_source_type('security_orchestration_policy')
                     .for_project_ids(project_ids)
                     .with_status(*::Ci::HasStatus::ALIVE_STATUSES)
                     .created_after(1.hour.ago)
                     .updated_after(1.hour.ago)
                     .limit(limit)
                     .count
        end

        active_builds + schedule_builds_count >= limit
      end

      def actions_for(schedule)
        policy = schedule.policy
        return [] if policy.blank?

        policy[:actions]
      end

      def log_error(current_user, schedule, message)
        ::Gitlab::AppJsonLogger.warn(
          build_structured_payload(
            security_orchestration_policy_configuration_id: schedule&.security_orchestration_policy_configuration&.id,
            user_id: current_user.id,
            message: message
          )
        )
      end
    end
  end
end
