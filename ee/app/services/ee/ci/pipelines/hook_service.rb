# frozen_string_literal: true

module EE
  module Ci
    module Pipelines
      module HookService
        def execute
          super
          return unless ::Feature.enabled?(:ai_flow_trigger_pipeline_hooks, project.root_group)

          project.execute_flow_triggers(hook_data, ::Ci::Pipelines::HookService::HOOK_NAME) unless pipeline.workload?
        end
      end
    end
  end
end
