# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module PopulateMetadata
            extend ::Gitlab::Utils::Override

            override :set_pipeline_name
            def set_pipeline_name
              policy_pipeline_name = policy_pipeline_metadata[:name]
              return super if policy_pipeline_name.blank?

              assign_to_metadata(name: policy_pipeline_name.strip)
            end

            private

            def policy_pipeline_metadata
              command.pipeline_policy_context.pipeline_execution_context.overridden_pipeline_metadata
            end
          end
        end
      end
    end
  end
end
