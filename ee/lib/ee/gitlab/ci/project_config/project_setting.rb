# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module ProjectConfig
        module ProjectSetting
          extend ::Gitlab::Utils::Override

          override :content
          def content
            return if pipeline_policy_context&.has_overriding_execution_policy_pipelines?

            super
          end
        end
      end
    end
  end
end
