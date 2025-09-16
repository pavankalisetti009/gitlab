# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class ExecuteService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize

        def initialize(project:, current_user:, params:)
          @flow = params[:flow]
          @flow_version = params[:flow_version]
          @execute_workflow = params[:execute_workflow]
          super
        end

        def execute
          return validate unless validate.success?
          return error_no_permissions unless allowed?

          flow_config = generate_flow_config

          return ServiceResponse.success(payload: { flow_config: flow_config.to_yaml }) unless execute_workflow

          execution_result = execute_workflow_service(flow_config)

          if execution_result.success?
            track_ai_item_events(
              'trigger_ai_catalog_item',
              { label: flow.item_type, property: 'manual', value: flow.id }
            )
          end

          execution_result
        end

        private

        attr_reader :flow, :flow_version, :execute_workflow

        def validate
          return error('Flow is required') unless flow && flow.flow?
          return error('Flow version is required') unless flow_version
          return error('Flow version must belong to the flow') unless flow_version.item == flow
          return error('Flow version must have steps') unless flow_version.def_steps.present?

          ServiceResponse.success
        end
        strong_memoize_attr :validate

        def execute_workflow_service(flow_config)
          params = {
            json_config: flow_config,
            container: flow.project,
            goal: flow_goal
          }

          ::Ai::Catalog::ExecuteWorkflowService.new(current_user, params).execute
        end

        def generate_flow_config
          payload_builder = ::Ai::Catalog::DuoWorkflowPayloadBuilder::Experimental.new(
            flow,
            flow_version.version
          )
          payload_builder.build
        end

        def flow_goal
          flow.description
        end
      end
    end
  end
end
