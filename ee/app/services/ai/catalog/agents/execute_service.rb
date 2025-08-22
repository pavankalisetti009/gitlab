# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class ExecuteService
        include Gitlab::Utils::StrongMemoize

        def initialize(agent, agent_version, current_user)
          @agent = agent
          @agent_version = agent_version
          @current_user = current_user
        end

        def execute
          return validate unless validate.success?
          return error_no_permissions unless allowed?

          return wrapped_agent_response if wrapped_agent_response.error?

          @flow = wrapped_agent_response.payload[:flow]

          flow_config = generate_flow_config
          yaml_config = flow_config.to_yaml

          ServiceResponse.success(payload: { flow_config: yaml_config })
        end

        private

        attr_reader :agent, :agent_version, :current_user, :flow

        def allowed?
          Ability.allowed?(current_user, :admin_ai_catalog_item, agent)
        end

        def error_no_permissions
          ServiceResponse.error(message: 'You have insufficient permission to execute this agent')
        end

        def validate
          return ServiceResponse.error(message: 'Agent is required') unless agent && agent.agent?
          return ServiceResponse.error(message: 'Agent version is required') unless agent_version

          unless agent_version.item == agent
            return ServiceResponse.error(message: 'Agent version must belong to the agent')
          end

          ServiceResponse.success
        end
        strong_memoize_attr :validate

        def wrapped_agent_response
          WrappedAgentFlowBuilder.new(agent, agent_version).execute
        end
        strong_memoize_attr :wrapped_agent_response

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
