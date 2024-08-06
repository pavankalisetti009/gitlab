# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module Command
            extend ::Gitlab::Utils::Override

            override :execution_policy_mode?
            def execution_policy_mode?
              !!execution_policy_dry_run
            end

            override :pipeline_policy_context
            def pipeline_policy_context
              @pipeline_policy_context ||= ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext.new(
                project: project,
                command: self
              )
            end
          end
        end
      end
    end
  end
end
