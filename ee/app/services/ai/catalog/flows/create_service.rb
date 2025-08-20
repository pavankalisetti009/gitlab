# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class CreateService < Ai::Catalog::BaseService
        include FlowHelper

        def execute
          return error_max_steps if max_steps_exceeded?
          return error_no_permissions unless allowed?
          return error(steps_validation_errors) unless steps_valid?

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::FLOW_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )
          version_params = {
            schema_version: SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: {
              triggers: [],
              steps: steps
            }
          }

          item = Ai::Catalog::Item.new(item_params)
          item.build_new_version(version_params)

          if item.save
            track_ai_item_events('create_ai_catalog_item', item.item_type)
            return ServiceResponse.success(payload: { item: item })
          end

          error_creating(item)
        end

        private

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create flow')
        end
      end
    end
  end
end
