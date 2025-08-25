# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class Experimental < Base
        FLOW_VERSION = 'experimental'
        FLOW_ENVIRONMENT = 'remote'
        AGENT_COMPONENT_TYPE = 'AgentComponent'
        DEFAULT_INPUTS = [{ 'from' => 'context:goal', 'as' => 'goal' }].freeze
        PROMPT_ID = 'workflow_catalog'
        PROMPT_VERSION = '^1.0.0'

        private

        def build_flow_config
          {
            'version' => FLOW_VERSION,
            'environment' => FLOW_ENVIRONMENT,
            'components' => build_components,
            'routers' => build_routers,
            'flow' => flow_configuration
          }
        end

        def build_components
          steps.filter_map do |step|
            build_agent_component(step)
          end
        end

        def build_routers
          routers = []

          steps.each_cons(2) do |current_step, next_step|
            routers << {
              'from' => step_unique_identifier(current_step),
              'to' => step_unique_identifier(next_step)
            }
          end

          routers << {
            'from' => step_unique_identifier(steps.last),
            'to' => 'end'
          }
        end

        def flow_configuration
          { 'entry_point' => step_unique_identifier(steps.first) }
        end

        def build_agent_component(step)
          agent = step[:agent]
          pinned_version_id = pinned_to_specific_version? ? step[:current_version_id] : nil
          definition = agent.definition(step[:pinned_version_prefix], pinned_version_id)

          {
            'name' => step_unique_identifier(step),
            'type' => AGENT_COMPONENT_TYPE,
            'prompt_id' => PROMPT_ID,
            'prompt_version' => PROMPT_VERSION,
            'inputs' => agent_inputs(step),
            'toolset' => agent_toolset(definition),
            'ui_log_events' => ui_log_events
          }
        end

        def agent_inputs(step)
          return DEFAULT_INPUTS if step[:idx] == 0

          previous_step = steps[step[:idx] - 1]
          previous_step_id = step_unique_identifier(previous_step)

          DEFAULT_INPUTS + [
            {
              'from' => "context:#{previous_step_id}.final_answer",
              'as' => 'previous_step_answer'
            },
            {
              'from' => "conversation_history:#{previous_step_id}",
              'as' => 'previous_step_msg_history'
            }
          ]
        end

        def agent_toolset(definition)
          definition.tool_names
        end

        # Required for rendering agent outputs on the UI
        def ui_log_events
          %w[
            on_tool_execution_success
            on_agent_final_answer
            on_tool_execution_failed
          ]
        end
      end
    end
  end
end
