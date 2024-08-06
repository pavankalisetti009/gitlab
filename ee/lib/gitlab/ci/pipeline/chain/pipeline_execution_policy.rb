# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        PipelineExecutionPolicy = Struct.new(:pipeline, :strategy) do
          def strategy_override_project_ci?
            strategy == :override_project_ci
          end
        end
      end
    end
  end
end
