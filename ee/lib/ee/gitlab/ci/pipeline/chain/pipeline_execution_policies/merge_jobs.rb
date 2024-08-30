# frozen_string_literal: true

# This step is only executed if Pipeline Execution Policies configurations were loaded in
# `PipelineExecutionPolicies::FindConfigs`, otherwise it's a no-op.
#
# It merges jobs from the policy pipelines saved on `command` onto the project pipeline.
# If a policy pipeline stage is not used in the project pipeline, all jobs from this stage are silently ignored.
#
# The step needs to be executed after `Populate` and `PopulateMetadata` steps to ensure that `pipeline.stages` are set,
# and before `StopDryRun` to ensure that the policy jobs are visible for the users when pipeline creation is simulated.
module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module PipelineExecutionPolicies
            module MergeJobs
              include ::Gitlab::Ci::Pipeline::Chain::Helpers
              include ::Gitlab::InternalEventsTracking

              def perform!
                return if command.execution_policy_mode? || command.pipeline_execution_policies.blank?

                clear_project_pipeline
                merge_policy_jobs
                track_internal_event(
                  'enforce_pipeline_execution_policy_in_project',
                  namespace: project.namespace,
                  project: project
                )
              rescue ::Gitlab::Ci::Pipeline::JobsInjector::DuplicateJobNameError => e
                error("Pipeline execution policy error: #{e.message}", failure_reason: :config_error)
              end

              def break?
                pipeline.errors.any?
              end

              private

              def clear_project_pipeline
                # We remove the project pipeline config in two scenarios;
                # 1. pipeline_execution_policy_forced?: It means that it is only
                # the DUMMY job to enforce the pipeline without project CI configuration.
                # 2. any policy uses `override_project_ci` strategy.
                # It means that we need to ignore the project CI configuration.
                unless pipeline.pipeline_execution_policy_forced? ||
                    command.pipeline_policy_context.has_overriding_pipeline_execution_policies?
                  return
                end

                pipeline.stages = []
              end

              def merge_policy_jobs
                command.pipeline_execution_policies.each do |policy|
                  # Return `nil` is equivalent to "never" otherwise provide the new name.
                  on_conflict = ->(job_name) { job_name + policy.suffix if policy.suffix_on_conflict? }

                  # Instantiate JobsInjector per policy pipeline to keep conflict-based job renaming isolated
                  job_injector = ::Gitlab::Ci::Pipeline::JobsInjector.new(
                    pipeline: pipeline,
                    declared_stages: command.yaml_processor_result.stages,
                    on_conflict: on_conflict)
                  policy.pipeline.stages.each do |stage|
                    job_injector.inject_jobs(jobs: stage.statuses, stage: stage) do |job|
                      job.set_execution_policy_job!

                      track_internal_event(
                        'execute_job_pipeline_execution_policy',
                        project: project,
                        namespace: project.namespace)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
