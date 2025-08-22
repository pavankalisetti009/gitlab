# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class UpdateService < Ai::Catalog::BaseService
        include FlowHelper

        def initialize(project:, current_user:, params:)
          @flow = params[:flow]
          super
        end

        def execute
          return error_max_steps if max_steps_exceeded?
          return error_no_permissions(payload: payload) unless allowed?
          return error('Flow not found') unless valid_flow?
          return error(steps_validation_errors) unless steps_valid?

          item_params = params.slice(:name, :description, :public)
          flow.assign_attributes(item_params)

          latest_version = flow.latest_version
          latest_version.definition = latest_version.definition.merge(steps: steps) if params.key?(:steps)
          if latest_version.definition_changed?
            latest_version.schema_version = ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION
          end

          if flow.save
            track_ai_item_events('update_ai_catalog_item', flow.item_type)
            return ServiceResponse.success(payload: payload)
          end

          error(flow.errors.full_messages)
        end

        private

        attr_reader :flow

        def valid_flow?
          flow && flow.flow?
        end

        def payload
          { flow: flow }
        end

        def error(message)
          super(message, payload: payload)
        end
      end
    end
  end
end
