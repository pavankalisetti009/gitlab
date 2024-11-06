# frozen_string_literal: true

module Security
  module ScanExecutionPolicies
    class CreatePipelineWorker # rubocop:disable Scalability/IdempotentWorker -- The worker should not run multiple times to avoid creating multiple pipelines
      include ApplicationWorker
      prepend Gitlab::ConditionalConcurrencyLimitControl
      include Gitlab::InternalEventsTracking

      CACHE_EXPIRES_IN = 1.second
      BATCH_SIZE = 250

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

        track_creation_event(project, schedule, actions.size, service_result[:status])

        return unless service_result[:status] == :error

        log_error(current_user, schedule, service_result[:message])
      end

      private

      def defer_job?(project_id, _, schedule_id, _)
        project = Project.find_by_id(project_id)
        return false unless project

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(schedule_id)
        return false unless schedule

        policy_configuration = schedule.security_orchestration_policy_configuration

        return false if policy_configuration.project?
        return false unless feature_enabled?(policy_configuration)

        schedule_builds_count = actions_for(schedule).count

        max_scheduled_scans_concurrency > 0 && reached_limit?(limit: max_scheduled_scans_concurrency,
          schedule_builds_count: schedule_builds_count, project: project, schedule_id: schedule_id)
      end

      # def project_ids(project)
      #   project.root_namespace.all_projects
      # end

      def max_scheduled_scans_concurrency
        Gitlab::CurrentSettings.security_policy_scheduled_scans_max_concurrency
      end

      def cache_key(schedule_id)
        "security_policy_concurrency_control:#{schedule_id}"
      end

      def reached_limit?(limit:, schedule_builds_count:, project:, schedule_id:)
        active_builds = Rails.cache.fetch(cache_key(schedule_id), expires_in: CACHE_EXPIRES_IN) do
          active_builds_in_all_projects = 0

          project.root_namespace.all_projects.each_batch(of: BATCH_SIZE) do |batch|
            project_ids = batch.pluck(:id) # rubocop:disable CodeReuse/ActiveRecord -- avoids cross-schema error

            active_builds_in_batch =
              ::Ci::Build.with_pipeline_source_type('security_orchestration_policy')
                         .for_project_ids(project_ids)
                         .with_status(*::Ci::HasStatus::ALIVE_STATUSES)
                         .created_after(1.hour.ago)
                         .updated_after(1.hour.ago)
                         .limit(limit)
                         .count

            active_builds_in_all_projects += active_builds_in_batch

            break if active_builds_in_all_projects + schedule_builds_count >= limit
          end

          active_builds_in_all_projects
        end

        active_builds + schedule_builds_count >= limit
      end

      def actions_for(schedule)
        policy = schedule.policy
        return [] if policy.blank?

        policy[:actions]
      end

      def track_creation_event(project, schedule, scans_count, result)
        track_internal_event(
          'enforce_scheduled_scan_execution_policy_in_project',
          project: project,
          additional_properties: {
            value: scans_count, # Number of enforced scans,
            label: result.to_s, # Was the creation of the pipeline successful,
            property: schedule.policy_source
          }
        )
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

      def feature_enabled?(policy_configuration)
        Feature.enabled?(:scan_execution_pipeline_concurrency_control, policy_configuration.namespace)
      end
    end
  end
end
