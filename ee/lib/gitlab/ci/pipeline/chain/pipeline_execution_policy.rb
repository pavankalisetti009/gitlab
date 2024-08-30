# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        PipelineExecutionPolicy = Struct.new(:pipeline, :config) do
          delegate :strategy, :suffix_strategy, :suffix, to: :config

          def strategy_override_project_ci?
            strategy == :override_project_ci
          end

          def suffix_on_conflict?
            suffix_strategy == :on_conflict
          end
        end
      end
    end
  end
end
