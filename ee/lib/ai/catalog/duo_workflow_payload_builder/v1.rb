# frozen_string_literal: true

module Ai
  module Catalog
    module DuoWorkflowPayloadBuilder
      class V1 < Base
        FLOW_VERSION = 'experimental'
        FLOW_ENVIRONMENT = 'remote'
        AGENT_COMPONENT_TYPE = 'AgentComponent'
        OUTPUT_CONTEXT = 'context:agent.answer'
        AGENT_INPUT = 'context:goal'
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
          agent_version_mappings.filter_map { |agent_mapping| build_agent_component(agent_mapping) }
        end

        def build_routers
          routers = []

          agents.each_cons(2) do |current_agent, next_agent|
            routers << {
              'from' => agent_unique_identifier(current_agent),
              'to' => agent_unique_identifier(next_agent)
            }
          end

          routers << {
            'from' => agent_unique_identifier(agents.last),
            'to' => 'end'
          }
        end

        def flow_configuration
          { 'entry_point' => agent_unique_identifier(agents.first) }
        end

        def build_agent_component(agent_mapping)
          agent = agent_mapping[:agent]
          version = agent_mapping[:version]
          definition = agent.definition(version)

          {
            'name' => agent_unique_identifier(agent),
            'type' => AGENT_COMPONENT_TYPE,
            'prompt_id' => PROMPT_ID,
            'prompt_version' => PROMPT_VERSION,
            'inputs' => [AGENT_INPUT],
            'output' => OUTPUT_CONTEXT,
            'toolset' => determine_toolset(definition),
            'ui_log_events' => ui_log_events
          }
        end

        def determine_toolset(definition)
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
