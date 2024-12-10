# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module Skip
            extend ::Gitlab::Utils::Override

            private

            override :skipped?
            def skipped?
              return super unless command.pipeline_policy_context&.has_execution_policy_pipelines?
              return super if command.pipeline_policy_context&.skip_ci_allowed?

              # We don't allow pipeline to be skipped if it has to run execution policy pipelines
              # and at least one pipeline is configured to not allow using skip_ci
              false
            end
          end
        end
      end
    end
  end
end
