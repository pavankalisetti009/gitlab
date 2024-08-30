# frozen_string_literal: true

module Security
  module PipelineExecutionPolicy
    # This is the maximum number of PEPs in a policy config file
    POLICY_LIMIT = 5
    SUFFIX_STRATEGIES = { on_conflict: 'on_conflict', never: 'never' }.freeze
    DEFAULT_SUFFIX_STRATEGY = :on_conflict
    POLICY_JOB_SUFFIX = ':policy'

    def self.build_policy_suffix(policy_project_id:, policy:, policy_index:)
      return if policy[:suffix] == SUFFIX_STRATEGIES[:never]

      "#{POLICY_JOB_SUFFIX}-#{policy_project_id}-#{policy_index}"
    end

    def active_pipeline_execution_policies
      pipeline_execution_policy.select { |config| config[:enabled] }.first(POLICY_LIMIT)
    end

    def pipeline_execution_policy
      policy_by_type(:pipeline_execution_policy)
    end
  end
end
