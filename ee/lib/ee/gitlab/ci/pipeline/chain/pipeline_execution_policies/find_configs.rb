# frozen_string_literal: true

# This step collects configurations for Pipeline Execution Policies and builds isolated pipelines for each policy.
# The resulting pipeline objects are saved on the `command`.
# The jobs of the policy pipelines are merged onto the project pipeline later in the chain,
# in the `PipelineExecutionPolicies::MergeJobs` step.
#
# The step needs to be executed:
# - After `AssignPartition` to ensure that all policy pipelines are built using the same `partition_id`.
# - Before `Skip` step to enforce pipeline with policies regardless of `ci.skip` options.
# - Before `Config::Content` step to be able to force the pipeline creation
#   with Pipeline Execution Policies if there is no `.gitlab-ci.yml` in the project.
#
# If there are applicable policies and they return an error, the pipeline creation will be aborted.
# If the policy pipelines are filtered out by rules, they are ignored and the pipeline creation continues as usual.
module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module PipelineExecutionPolicies
            module FindConfigs
              include ::Gitlab::Ci::Pipeline::Chain::Helpers
              include ::Gitlab::Utils::StrongMemoize
              extend ::Gitlab::Utils::Override

              override :perform!
              def perform!
                return if command.execution_policy_mode?
                return if pipeline.dangling?
                return if pipeline_execution_policy_configs.empty?

                command.execution_policy_pipelines = []
                pipeline_execution_policy_configs.each do |config|
                  response = create_pipeline(config.content)
                  pipeline = response.payload

                  if response.success?
                    command.execution_policy_pipelines << ::Security::PipelineExecutionPolicy::Pipeline.new(
                      pipeline: pipeline, config: config)
                  elsif pipeline.filtered_as_empty?
                    # no-op: we ignore empty pipelines
                  else
                    return error("Pipeline execution policy error: #{response.message}", failure_reason: :config_error)
                  end
                end
              end

              override :break?
              def break?
                pipeline.errors.any?
              end

              private

              def pipeline_execution_policy_configs
                ::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies.new(project).configs
              end
              strong_memoize_attr :pipeline_execution_policy_configs

              def create_pipeline(content)
                ::Ci::CreatePipelineService
                  .new(command.project, command.current_user, ref: command.ref, partition_id: pipeline.partition_id)
                  .execute(command.source,
                    execution_policy_dry_run: true,
                    content: content,
                    merge_request: command.merge_request, # This is for supporting merge request pipelines
                    ignore_skip_ci: true # We can exit early from `Chain::Skip` by setting this parameter
                    # Additional parameters will be added in https://gitlab.com/gitlab-org/gitlab/-/issues/462004
                  )
              end
            end
          end
        end
      end
    end
  end
end
