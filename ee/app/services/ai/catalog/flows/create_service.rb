# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class CreateService < Ai::Catalog::BaseService
        include FlowHelper

        def execute
          return error_no_permissions unless allowed?
          return error(MAX_STEPS_ERROR) if max_steps_exceeded?
          return error_no_permissions unless agents_allowed?
          return error(steps_validation_errors) unless steps_valid?

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::FLOW_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )
          version_params = {
            schema_version: ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: {
              triggers: [],
              steps: steps
            }
          }
          version_params[:release_date] = Time.zone.now if params[:release] == true

          item = Ai::Catalog::Item.new(item_params)
          item.build_new_version(version_params)

          if save_item(item)
            track_ai_item_events('create_ai_catalog_item', { label: item.item_type })
            return ServiceResponse.success(payload: { item: item })
          end

          error_creating(item)
        end

        private

        def save_item(item)
          Ai::Catalog::Item.transaction do
            item.save!
            item.update!(latest_released_version: item.latest_version) if item.latest_version.released?
            populate_dependencies(item.latest_version, delete_no_longer_used_dependencies: false)
            true
          end
        rescue ActiveRecord::RecordInvalid
          false
        end

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create flow')
        end
      end
    end
  end
end
