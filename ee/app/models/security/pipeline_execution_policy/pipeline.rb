# frozen_string_literal: true

# This class is the object representation of a pipeline created by a policy
module Security
  module PipelineExecutionPolicy
    class Pipeline
      def initialize(pipeline:, policy_config:)
        @pipeline = pipeline
        @policy_config = policy_config
      end

      attr_reader :pipeline, :policy_config

      delegate :suffix_strategy, :suffix, :suffix_on_conflict?, to: :policy_config

      def strategy
        policy_config.config_strategy
      end

      def strategy_override_project_ci?
        strategy == :override_project_ci
      end
    end
  end
end
