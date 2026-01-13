# frozen_string_literal: true

module ComplianceManagement
  class FrameworkEvaluationSchedulerWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- does not require context

    version 1
    urgency :throttled
    data_consistency :sticky
    feature_category :compliance_management
    sidekiq_options retry: false
    idempotent!

    FRAMEWORK_BATCH_SIZE = 100
    PROJECT_BATCH_SIZE = 100

    def perform
      if Feature.enabled?(:optimize_framework_worker_query, type: :gitlab_com_derisk) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- feature flag is for cronjob query optimization so cannot add actor
        perform_optimized
      else
        perform_legacy
      end
    end

    private

    def perform_legacy
      active_control_frameworks.each_batch(of: FRAMEWORK_BATCH_SIZE) do |batch|
        batch.each do |framework|
          enqueue_framework_evaluation(framework)
        end
      end
    end

    def active_control_frameworks
      ComplianceManagement::Framework.with_active_controls
    end

    def enqueue_framework_evaluation(framework)
      framework.projects.each_batch(of: PROJECT_BATCH_SIZE) do |projects_batch|
        ProjectComplianceEvaluatorWorker.perform_async(
          framework.id,
          projects_batch.pluck_primary_key
        )
      end
    end

    def perform_optimized
      active_framework_ids = ComplianceManagement::Framework.active_framework_ids

      return if active_framework_ids.empty?

      active_framework_ids.each_slice(FRAMEWORK_BATCH_SIZE) do |framework_ids_batch|
        enqueue_batch_evaluations(framework_ids_batch)
      end
    end

    def enqueue_batch_evaluations(framework_ids)
      framework_project_map = ComplianceManagement::ComplianceFramework::ProjectSettings
                                .framework_project_mappings(framework_ids)

      framework_project_map.each do |framework_id, project_ids|
        enqueue_framework_projects_evaluation(framework_id, project_ids)
      end
    end

    def enqueue_framework_projects_evaluation(framework_id, project_ids)
      project_ids.each_slice(PROJECT_BATCH_SIZE) do |project_ids_batch|
        ProjectComplianceEvaluatorWorker.perform_async(
          framework_id,
          project_ids_batch
        )
      end
    end
  end
end
