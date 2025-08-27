# frozen_string_literal: true

FactoryBot.define do
  factory(
    :pipeline_execution_policy_pipeline,
    class: '::Security::PipelineExecutionPolicy::Pipeline'
  ) do
    pipeline factory: :ci_empty_pipeline
    policy_config factory: :pipeline_execution_policy_config

    skip_create
    initialize_with do
      new(**attributes)
    end

    trait :override_project_ci do
      policy_config factory: [:pipeline_execution_policy_config, :override_project_ci]
    end

    trait :suffix_never do
      policy_config factory: [:pipeline_execution_policy_config, :suffix_never]
    end

    trait :skip_ci_allowed do
      policy_config factory: [:pipeline_execution_policy_config, :skip_ci_allowed]
    end

    trait :skip_ci_disallowed do
      policy_config factory: [:pipeline_execution_policy_config, :skip_ci_disallowed]
    end

    transient do
      job_script { nil }
    end

    after(:build) do |instance, evaluator|
      next unless evaluator.job_script

      job = instance.pipeline.stages[0].statuses[0]
      updated_options = { script: evaluator.job_script }

      # TODO: Remove this when FF `stop_writing_builds_metadata` is removed.
      # https://gitlab.com/gitlab-org/gitlab/-/issues/552065
      job.metadata.write_attribute(:config_options, updated_options)
      next unless job.job_definition

      updated_config = job.job_definition.config.merge(options: updated_options)
      job.job_definition.write_attribute(:config, updated_config)
    end
  end
end
