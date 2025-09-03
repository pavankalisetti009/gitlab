# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class ExecuteService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize

        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          @agent_version = params[:agent_version]
          @execute_workflow = params[:execute_workflow]
          super
        end

        def execute
          return validate unless validate.success?
          return error_no_permissions unless allowed?

          return wrapped_agent_response if wrapped_agent_response.error?

          @flow = wrapped_agent_response.payload[:flow]

          flow_config = generate_flow_config

          return ServiceResponse.success(payload: { flow_config: flow_config.to_yaml }) unless execute_workflow

          execution_result = execute_workflow_service(flow_config)

          if execution_result.success?
            track_ai_item_events(
              'trigger_ai_catalog_item',
              { label: agent.item_type, property: "manual", value: agent.id }
            )
          end

          execution_result
        end

        private

        attr_reader :agent, :agent_version, :flow, :execute_workflow

        def validate
          return error('Agent is required') unless agent && agent.agent?
          return error('Agent version is required') unless agent_version

          return error('Agent version must belong to the agent') unless agent_version.item == agent

          if execute_workflow
            return error('Agent must have a project') unless agent.project

            return error('Agent version must have user_prompt') unless agent_version.def_user_prompt.present?
          end

          ServiceResponse.success
        end
        strong_memoize_attr :validate

        def wrapped_agent_response
          WrappedAgentFlowBuilder.new(agent, agent_version).execute
        end
        strong_memoize_attr :wrapped_agent_response

        def execute_workflow_service(flow_config)
          params = {
            json_config: flow_config,
            container: agent.project,
            goal: agent_version.def_user_prompt
          }

          ::Ai::Catalog::ExecuteWorkflowService.new(current_user, params).execute
        end

        def generate_flow_config
          payload_builder = ::Ai::Catalog::DuoWorkflowPayloadBuilder::ExperimentalAgentWrapper.new(
            flow,
            flow.latest_version
          )
          payload_builder.build
        end
      end
    end
  end
end
