# frozen_string_literal: true

# This class is the object representation of a single entry in the policy.yml
module Security
  module PipelineExecutionPolicy
    class Config
      include Gitlab::Utils::StrongMemoize

      DEFAULT_SUFFIX_STRATEGY = 'on_conflict'
      SUFFIX_STRATEGIES = { on_conflict: 'on_conflict', never: 'never' }.freeze
      POLICY_JOB_SUFFIX = ':policy'

      attr_reader :content, :config_strategy, :suffix_strategy, :policy_project_id, :policy_index

      def initialize(policy:, policy_project_id:, policy_index:)
        @content = policy.fetch(:content).to_yaml
        @policy_project_id = policy_project_id
        @policy_index = policy_index
        @config_strategy = policy.fetch(:pipeline_config_strategy).to_sym
        @suffix_strategy = policy[:suffix] || DEFAULT_SUFFIX_STRATEGY
      end

      def suffix
        return if suffix_strategy == SUFFIX_STRATEGIES[:never]

        [POLICY_JOB_SUFFIX, policy_project_id, policy_index].join("-")
      end
      strong_memoize_attr :suffix

      def suffix_on_conflict?
        suffix_strategy == SUFFIX_STRATEGIES[:on_conflict]
      end
    end
  end
end
