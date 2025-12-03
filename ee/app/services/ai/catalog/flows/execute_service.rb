# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class ExecuteService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize

        def initialize(project:, current_user:, params:)
          @item_consumer = params[:item_consumer]
          @execute_workflow = params[:execute_workflow]
          @event_type = params[:event_type]
          @user_prompt = params[:user_prompt]
          @service_account = params[:service_account]

          if @item_consumer
            @flow = @item_consumer.item
            @flow_version = @flow&.resolve_version(@item_consumer.pinned_version_prefix)
          end

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
              { label: flow.item_type, property: event_type, value: flow.id }
            )
          end

          execution_result
        end

        private

        attr_reader :flow, :flow_version, :event_type, :user_prompt, :execute_workflow, :item_consumer, :service_account

        def allowed?
          Ability.allowed?(current_user, :execute_ai_catalog_item, item_consumer)
        end

        def validate
          return error('Item consumer is required') unless item_consumer
          return error('Item consumer must be associated with a flow') unless flow
          return error('Item must be a flow type') unless flow.flow?
          return error('Flow version could not be resolved from pinned version') unless flow_version
          return error('Flow version is in draft state and cannot be executed') if flow_version.draft?
          return error('Trigger event type is required') if event_type.blank?

          ServiceResponse.success
        end
        strong_memoize_attr :validate

        def execute_workflow_service(flow_config)
          params = {
            json_config: flow_config,
            container: item_consumer.project,
            goal: flow_goal,
            item_version: flow_version,
            service_account: service_account
          }

          ::Ai::Catalog::ExecuteWorkflowService.new(current_user, params).execute
        end

        def generate_flow_config
          flow_version.definition.except('yaml_definition')
        end

        def flow_goal
          user_prompt || flow.description
        end
      end
    end
  end
end
