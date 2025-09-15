# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class UpdateService < Items::BaseUpdateService
        extend Gitlab::Utils::Override
        include FlowHelper

        private

        override :validate_item
        def validate_item
          return error('Flow not found') unless item && item.flow?
          return error(MAX_STEPS_ERROR) if max_steps_exceeded?
          return error_no_permissions(payload: payload) unless agents_allowed?

          error(steps_validation_errors) unless steps_valid?
        end

        override :build_version_params
        def build_version_params(latest_version)
          return {} unless params.key?(:steps)

          {
            definition: latest_version.definition.merge(steps: steps)
          }
        end

        override :save_item
        def save_item
          Ai::Catalog::Item.transaction do
            populate_dependencies(item.latest_version) if item.save && item.latest_version.saved_changes?
          end
        end

        override :latest_schema_version
        def latest_schema_version
          Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION
        end
      end
    end
  end
end
