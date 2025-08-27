# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class ExecuteService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize

        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          @agent_version = params[:agent_version]
          super
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

        attr_reader :agent, :agent_version, :flow

        def validate
          return error('Agent is required') unless agent && agent.agent?
          return error('Agent version is required') unless agent_version

          return error('Agent version must belong to the agent') unless agent_version.item == agent

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
