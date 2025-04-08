# frozen_string_literal: true

module Security
  module PipelineExecutionPolicy
    def active_pipeline_execution_policies
      pipeline_execution_policy.select { |config| config[:enabled] }.first(policy_limit)
    end

    def pipeline_execution_policy
      policy_by_type(:pipeline_execution_policy)
    end

    private

    def policy_limit
      Security::SecurityOrchestrationPolicies::LimitService
        .new(container: project)
        .pipeline_execution_policies_per_configuration_limit
    end
  end
end
