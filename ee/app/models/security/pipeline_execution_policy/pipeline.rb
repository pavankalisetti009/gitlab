# frozen_string_literal: true

# This class is the object representation of a pipeline created by a policy
module Security
  module PipelineExecutionPolicy
    class Pipeline
      def initialize(pipeline:, config:)
        @pipeline = pipeline
        @config = config
      end

      attr_reader :pipeline, :config

      delegate :suffix_strategy, :suffix, :suffix_on_conflict?, to: :config

      def strategy
        config.config_strategy
      end

      def strategy_override_project_ci?
        strategy == :override_project_ci
      end
    end
  end
end
