# frozen_string_literal: true

require Rails.root.join('spec/support/helpers/ci/job_factory_helpers')

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

      Ci::JobFactoryHelpers.mutate_temp_job_definition(job, options: updated_options)
    end
  end
end
